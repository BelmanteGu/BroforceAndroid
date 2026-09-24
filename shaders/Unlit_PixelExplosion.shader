// Rewrite of the game's "Unlit/PixelExplosion" for GLES3.
// Same name and properties as the original, so existing materials pick it up.
// Transcribed from the original pass: the particle's custom vertex streams carry the
// rotation/scale (TEXCOORD1.zw, TEXCOORD2.x), noise parameters (TEXCOORD2.yzw) and
// ramp controls (TEXCOORD0). The explosion shape is sampled pixel-snapped in world
// space, eroded by scrolling noise, and coloured through _Ramp.
Shader "Unlit/PixelExplosion" {
	Properties {
		_MainTex ("Texture", 2D) = "white" {}
		_Ramp ("Ramp", 2D) = "white" {}
		_Brightness ("Brightness", Float) = 1
		_WorldToPixel ("World To Pixel", Float) = 1
		_UseSheet ("Use Sheet", Float) = 0
		_ColourAdd ("Colour Add", Float) = 0
		_RedRises ("Red Rises", Float) = 0
		_SheetWidth ("Sheet Width", Float) = 1
		_SheetHeight ("Sheet Height", Float) = 1
	}
	SubShader {
		Tags { "Queue"="AlphaTest" "RenderType"="TransparentCutout" }
		LOD 100

		Pass {
			ZTest LEqual
			ZWrite On
			Cull Back

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"

			sampler2D _MainTex;
			sampler2D _Ramp;
			float _Brightness;
			float _WorldToPixel;

			struct appdata {
				float4 vertex : POSITION;
				float4 stream0 : TEXCOORD0;   // x,y: ramp erosion weights; z: ramp offset; w: threshold
				float4 stream1 : TEXCOORD1;   // xy: shape uv; zw: scale
				float4 stream2 : TEXCOORD2;   // x: rotation; y: noise scroll; z: noise scale; w: unused
			};

			struct v2f {
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
				float2 worldXY : TEXCOORD1;
				float4 rot : TEXCOORD2;       // rows of the inverse rotation/scale
				float3 noise : TEXCOORD3;
				float4 ramp : TEXCOORD4;
			};

			v2f vert (appdata v) {
				v2f o;
				float4 world = mul(unity_ObjectToWorld, v.vertex);
				o.pos = mul(UNITY_MATRIX_VP, world);
				o.worldXY = world.xy;
				o.uv = v.stream1.xy;
				float a = v.stream2.x;
				o.rot.xy = float2(cos(a), -sin(a)) / v.stream1.z;
				o.rot.zw = float2(sin(a), cos(a)) / v.stream1.w;
				o.noise = v.stream2.yzw;
				o.ramp = v.stream0;
				return o;
			}

			fixed4 frag (v2f i) : SV_Target {
				// Scrolling noise, sampled on the world-space pixel grid.
				float2 noiseUV = i.worldXY * i.noise.z * 0.01 + float2(0, i.noise.y * _Time.y);
				float2 snapped = floor(noiseUV * _WorldToPixel) / _WorldToPixel;
				float2 cellOffset = frac(i.worldXY - snapped) * 0.01;
				noiseUV = frac(noiseUV - cellOffset * i.noise.z);
				float n = tex2D(_MainTex, noiseUV).z * 2 - 1;
				float erodeA = 1 + 5 * i.noise.x * n;
				float erodeB = 1 + i.noise.x * n;

				// Shape, sampled at the pixel-snapped position.
				float2 d = i.worldXY - floor(i.worldXY * _WorldToPixel) / _WorldToPixel;
				float len = length(d);
				float2 dn = d * rsqrt(max(dot(d, d), 1e-12));
				float2 uv = saturate(i.uv - len * float2(dot(dn, i.rot.xy), dot(dn, i.rot.zw)));
				float4 s = tex2D(_MainTex, uv);

				float shape = saturate(saturate(s.x * i.ramp.x + s.w) - s.y * i.ramp.y);
				clip(shape * erodeA - 1 + i.ramp.w * 0.99);

				float rampU = saturate(erodeB * (s.x * i.ramp.x + i.ramp.z - s.y * i.ramp.y));
				fixed4 c = tex2D(_Ramp, float2(rampU, 0.5));
				c.rgb = c.rgb + c.a * (c.rgb * _Brightness - c.rgb);
				return c;
			}
			ENDCG
		}
	}
}
