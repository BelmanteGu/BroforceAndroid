// Rewrite of the game's "Image Effects/Free Lives Refraction" for GLES3 (full-screen blit).
// _RefractTex (rgb centred on 0.502) offsets the screen uv by .rb * _SpeedStrength.w and
// splits red/green-blue horizontally by .g * _SpeedStrength.y (chromatic aberration); blue
// is blended between the two taps by .g. Opaque output. _Color and _SpeedStrength.xz are
// unused by the original pass (kept for material/script compatibility).
Shader "Image Effects/Free Lives Refraction" {
	Properties {
		_SpeedStrength ("Speed / Strength", Vector) = (0,0.01,0,0.05)
		_RefractTex ("Refraction (RGB)", 2D) = "gray" {}
		_Color ("Color", Color) = (1,1,1,1)
		_MainTex ("Base (RGB)", 2D) = "white" {}
	}
	SubShader {
		Pass {
			Blend Off
			ZTest Always
			ZWrite Off
			Cull Off

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"

			sampler2D _MainTex;
			float4 _MainTex_TexelSize;
			sampler2D _RefractTex;
			float4 _SpeedStrength;

			struct v2f {
				float4 pos : SV_POSITION;
				float4 uv : TEXCOORD0;      // xy: _MainTex, zw: _RefractTex (flipped if needed)
			};

			v2f vert (appdata_img v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv = v.texcoord.xyxy;
				#if UNITY_UV_STARTS_AT_TOP
				if (_MainTex_TexelSize.y < 0)
					o.uv.w = 1 - o.uv.w;
				#endif
				return o;
			}

			fixed4 frag (v2f i) : SV_Target {
				float3 r = tex2D(_RefractTex, i.uv.zw).rgb;
				float shift = (r.g - 0.502) * _SpeedStrength.y;
				float2 uv = (r.rb - 0.502) * _SpeedStrength.w + i.uv.xy;
				fixed4 a = tex2D(_MainTex, uv - float2(shift, 0));
				fixed4 b = tex2D(_MainTex, uv + float2(shift, 0));
				return fixed4(a.r, b.g, lerp(b.b, a.b, r.g), 1);
			}
			ENDCG
		}
	}
}
