"""Dump a readable reference for shaders exported by AssetRipper in YAML mode.

For each shader it prints the properties, per-pass render state and tags, and the
D3D11 disassembly of every program (via Windows' own d3dcompiler_47.dll). This is a
reference for rewriting the shaders in GLSL-compatible CG, not something to commit:
the output is derived from the game's compiled shaders.

Usage (Windows, Python 3):
  ./scripts/export.ps1 -ShaderMode Yaml -Name unity-shaderyaml
  python scripts/shader-dump.py export/unity-shaderyaml/ExportedProject/Assets export/shader-reference
"""
import ctypes
import os
import re
import struct
import sys

# ---- LZ4 block decompression (Unity compresses the program blob with LZ4) ----

def lz4_block(src, size):
    dst = bytearray()
    i = 0
    while i < len(src):
        tok = src[i]; i += 1
        lit = tok >> 4
        if lit == 15:
            while True:
                b = src[i]; i += 1; lit += b
                if b != 255:
                    break
        dst += src[i:i + lit]; i += lit
        if i >= len(src) or len(dst) >= size:
            break
        off = src[i] | (src[i + 1] << 8); i += 2
        ml = tok & 15
        if ml == 15:
            while True:
                b = src[i]; i += 1; ml += b
                if b != 255:
                    break
        ml += 4
        for _ in range(ml):
            dst.append(dst[-off])
    return bytes(dst)

# ---- D3DDisassemble through d3dcompiler_47.dll ----

_d3d = ctypes.WinDLL('d3dcompiler_47.dll')

def disassemble(program):
    blob = ctypes.c_void_p()
    hr = _d3d.D3DDisassemble(ctypes.c_char_p(program), ctypes.c_size_t(len(program)), 0, None, ctypes.byref(blob))
    if hr != 0:
        return '<D3DDisassemble failed 0x%08x>' % (hr & 0xffffffff)
    vtable = ctypes.cast(ctypes.cast(blob, ctypes.POINTER(ctypes.c_void_p))[0], ctypes.POINTER(ctypes.c_void_p))
    get_ptr = ctypes.WINFUNCTYPE(ctypes.c_void_p, ctypes.c_void_p)(vtable[3])
    get_size = ctypes.WINFUNCTYPE(ctypes.c_size_t, ctypes.c_void_p)(vtable[4])
    text = ctypes.string_at(get_ptr(blob), get_size(blob)).decode(errors='replace')
    keep = []
    for l in text.splitlines():
        if not l.strip():
            continue
        if l.startswith('//'):
            # Keep what's needed to map registers to names: cbuffer layouts,
            # resource bindings and the input/output signatures.
            body = l[2:].strip()
            if not re.search(r'Offset:|^cbuffer|texture |sampler |^(POSITION|COLOR|TEXCOORD|NORMAL|TANGENT|SV_)', body):
                continue
            l = '// ' + re.sub(r'\s+', ' ', body)
        keep.append(l)
    return '\n'.join(keep)

# ---- YAML helpers (the files are regular enough for regexes) ----

BLEND = ['Zero', 'One', 'DstColor', 'SrcColor', 'OneMinusDstColor', 'SrcAlpha', 'OneMinusSrcColor',
         'DstAlpha', 'OneMinusDstAlpha', 'SrcAlphaSaturate', 'OneMinusSrcAlpha']
ZTEST = ['Disabled', 'Never', 'Less', 'Equal', 'LEqual', 'Greater', 'NotEqual', 'GEqual', 'Always']
CULL = ['Off', 'Front', 'Back']

def val(block, key):
    m = re.search(r'\b' + key + r':\s*\n\s*val:\s*(-?[\d.]+)', block)
    return float(m.group(1)) if m else None

def colmask(v):
    v = int(v)
    return ''.join(c for bit, c in ((8, 'R'), (4, 'G'), (2, 'B'), (1, 'A')) if v & bit) or '0'

def describe_state(block):
    src, dst = val(block, 'srcBlend'), val(block, 'destBlend')
    parts = []
    parts.append('Blend Off' if (src, dst) == (1, 0) else 'Blend %s %s' % (BLEND[int(src)], BLEND[int(dst)]))
    z = val(block, 'zTest'); parts.append('ZTest %s' % (ZTEST[int(z)] if z is not None and 0 <= z < 9 else z))
    zw = val(block, 'zWrite'); parts.append('ZWrite %s' % ('On' if zw else 'Off'))
    c = val(block, 'culling'); parts.append('Cull %s' % (CULL[int(c)] if c is not None and 0 <= c < 3 else c))
    cm = val(block, 'colMask')
    if cm is not None and int(cm) != 15:
        parts.append('ColorMask %s' % colmask(cm))
    of, ou = val(block, 'offsetFactor'), val(block, 'offsetUnits')
    if of or ou:
        parts.append('Offset %g, %g' % (of, ou))
    return '  '.join(parts)

def programs(text):
    blob = re.search(r'compressedBlob: ([0-9a-f]+)', text)
    if not blob:
        return []
    blob = bytes.fromhex(blob.group(1))
    clen = struct.unpack('<I', bytes.fromhex(re.search(r'compressedLengths: ([0-9a-f]+)', text).group(1))[:4])[0]
    dlen = struct.unpack('<I', bytes.fromhex(re.search(r'decompressedLengths: ([0-9a-f]+)', text).group(1))[:4])[0]
    data = lz4_block(blob[:clen], dlen)
    # Header: entry count, then (offset, length) per blob index. m_BlobIndex refers to
    # these entries, which aren't necessarily in file order.
    count = struct.unpack_from('<I', data, 0)[0]
    out = []
    for k in range(count):
        off, length = struct.unpack_from('<II', data, 4 + 8 * k)
        pos = data.find(b'DXBC', off, off + length)
        if pos < 0:
            out.append('<no DXBC in blob entry %d>' % k)
            continue
        size = struct.unpack_from('<I', data, pos + 24)[0]
        out.append(disassemble(data[pos:pos + size]))
    return out

def bindings(text):
    """Map each blob index to 'register = name' lines, from the serialized subprograms.

    Shipped shaders have no reflection data, so the only way to know that cb0[3].y is,
    say, _WorldToPixel is the parameter table Unity keeps next to each program."""
    names = {}
    result = {}
    cur = None          # current subprogram dict
    cb_params = None    # params of the constant buffer being read
    section = None
    lines = text.splitlines()
    i = 0
    while i < len(lines):
        line = lines[i]
        s = line.strip()
        if s.lstrip('- ') == 'm_NameIndices:':
            names = {}
            j = i + 1
            while j < len(lines) and re.match(r'\s+[\w$]+: -?\d+$', lines[j]) and len(lines[j]) - len(lines[j].lstrip()) > len(line) - len(line.lstrip()):
                k, v = lines[j].strip().rsplit(': ', 1)
                names[int(v)] = k
                j += 1
            i = j
            continue
        m = re.match(r'm_BlobIndex: (\d+)', s)
        if m:
            cur = {'tex': [], 'cb': [], 'bind': {}, 'names': dict(names)}
            result[int(m.group(1))] = cur
            section = None
        elif cur is not None:
            if s.startswith('m_TextureParams:'):
                section = 'tex'
            elif s.startswith('m_ConstantBuffers:'):
                section = 'cbs'
            elif s.startswith('m_ConstantBufferBindings:'):
                section = 'bind'
            elif s.startswith(('m_UAVParams', 'm_Samplers', 'm_ShaderRequirements', 'm_BufferParams')):
                section = None
            elif section == 'tex':
                m = re.match(r'- m_NameIndex: (-?\d+)', s)
                if m:
                    idx = int(re.search(r'm_Index: (\d+)', lines[i + 1]).group(1))
                    cur['tex'].append((idx, int(m.group(1))))
            elif section == 'cbs':
                m = re.match(r'- m_NameIndex: (-?\d+)', s)
                if m and line.startswith('            - '):  # a constant buffer entry
                    cb_params = {'name': int(m.group(1)), 'params': []}
                    cur['cb'].append(cb_params)
                elif m and cb_params is not None:          # a parameter inside it
                    idx = int(re.search(r'm_Index: (\d+)', lines[i + 1]).group(1))
                    cb_params['params'].append((idx, int(m.group(1))))
            elif section == 'bind':
                m = re.match(r'- m_NameIndex: (-?\d+)', s)
                if m:
                    reg = int(re.search(r'm_Index: (\d+)', lines[i + 1]).group(1))
                    cur['bind'][int(m.group(1))] = reg
        i += 1

    out = {}
    for blob, sp in result.items():
        n = sp['names']
        rows = ['t%d = %s' % (reg, n.get(ni, ni)) for reg, ni in sp['tex']]
        for cb in sp['cb']:
            reg = sp['bind'].get(cb['name'], '?')
            for off, ni in cb['params']:
                rows.append('cb%s[%d].%s = %s' % (reg, off // 16, 'xyzw'[(off % 16) // 4], n.get(ni, ni)))
        out[blob] = rows
    return out

def dump(path):
    text = open(path, encoding='utf-8').read()
    name = re.search(r'm_Name: (.+)', text).group(1).strip()
    lines = ['# ' + name, '']
    props = re.findall(r'- m_Name: (_\w+)\s*\n\s*m_Description: (.*)\n(?:.*\n){0,3}?\s*m_Type: (\d)', text)
    if props:
        kinds = {0: 'Color', 1: 'Vector', 2: 'Float', 3: 'Range', 4: 'Texture'}
        lines.append('Properties: ' + ', '.join('%s (%s)' % (p[0], kinds.get(int(p[2]), p[2])) for p in props))
    for q in sorted(set(re.findall(r'QUEUE: (\S+)', text))):
        lines.append('Queue: ' + q)
    for rt in sorted(set(re.findall(r'RENDERTYPE: (\S+)', text))):
        lines.append('RenderType: ' + rt)
    for kw in sorted(set(re.findall(r'm_Name: (\w+_ON|\w+_OFF)\b', text))):
        lines.append('Keyword: ' + kw)
    for i, state in enumerate(re.findall(r'm_State:\n([\s\S]*?)m_Tags:', text)):
        lines.append('Pass %d: %s' % (i, describe_state(state)))
    try:
        binds = bindings(text)
    except Exception as e:  # the table is a convenience; never lose the disassembly over it
        binds = {}
        lines.append('(bindings not parsed: %s)' % e)
    for i, asm in enumerate(programs(text)):
        lines += ['', '## program %d' % i]
        lines += ['- ' + r for r in binds.get(i, [])]
        lines += ['```', asm, '```']
    return name, '\n'.join(lines) + '\n'

def main():
    src, dst = sys.argv[1], sys.argv[2]
    os.makedirs(dst, exist_ok=True)
    count = 0
    for root, _, files in os.walk(src):
        for f in sorted(files):
            if not f.endswith('.asset'):
                continue
            path = os.path.join(root, f)
            with open(path, encoding='utf-8', errors='replace') as fh:
                if '!u!48 ' not in fh.read(400):  # class 48 = Shader
                    continue
            try:
                name, text = dump(path)
            except Exception as e:  # keep going; one odd shader shouldn't stop the dump
                print('skip %s: %s' % (path, e))
                continue
            safe = re.sub(r'[^\w\- ]', '_', name)
            with open(os.path.join(dst, safe + '.md'), 'w', encoding='utf-8') as out:
                out.write(text)
            count += 1
    print('wrote %d shader references to %s' % (count, dst))

if __name__ == '__main__':
    main()
