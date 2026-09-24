// Rewrite of the game's "Custom/Starfield" for GLES3 (hyperspace star tunnel).
// Marches up to _Density (max 16) layers along a square "tunnel" ray from the quad centre;
// each 1x1 cell picks a phase from _MainTex.a, and draws a round star of size _Width whose
// RGB is split by distance (_Params: x depth scale, y spread, z RGB offset, w falloff).
// Result * _Color, doubled. Opaque, depth write on.
Shader "Custom/Starfield" {
	Properties {
		_Color ("Color", Color) = (0.5,0.5,0.5,1)
		_MainTex ("Noise (A)", 2D) = "white" {}
		_Params ("Params (depth, spread, rgb offset, falloff)", Vector) = (1,1,0.1,1)
		_Density ("Density (layers, max 16)", Float) = 8
		_Distance ("Distance", Float) = 10
		_Width ("Width", Float) = 1
	}
	SubShader {
		Tags { "Queue"="Geometry" }

		Pass {
			Blend Off
			ZTest LEqual
			ZWrite On
			Cull Back

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 3.0
			#include "UnityCG.cginc"

			sampler2D _MainTex;
			fixed4 _Color;
			float4 _Params;
			float _Density;
			float _Distance;
			float _Width;

			struct appdata {
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f {
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
			};

			v2f vert (appdata v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				return o;
			}

			fixed4 frag (v2f i) : SV_Target {
				float2 p = i.uv * 2 - 1;
				float m = max(abs(p.x), abs(p.y));
				float3 dir = float3(p, 1) / m;
				float3 pos = dir * 2 + 0.5;
				float t = frac(_Time.y * 0.1);
				float invFalloff = 1 / _Params.w;
				float halfOffset = _Params.z * 0.5;
				float3 acc = 0;

				// NOTE: the original treats _Density as an integer layer count (fully unrolled
				// to 16 layers); here it is compared as a float against a constant-bound loop.
				for (int n = 0; n < 16; n++) {
					if ((float)n >= _Density)
						break;
					float2 cell = (trunc(pos.xy) + 0.5) * (1.0 / 256.0);
					float phase = frac(tex2D(_MainTex, cell).a * 8 - t);
					float d = (_Distance * phase - pos.z * _Params.x) * _Params.y;
					float star = max(1 - length(frac(pos.xy) - 0.5) * 8 / _Width, 0);
					star *= star;
					float3 rgb = max(1 - abs(float3(d + halfOffset, d, d - halfOffset)) * invFalloff, 0);
					acc += rgb * ((1 - phase) * 1.5) * star;
					pos += dir;
				}

				fixed4 c = fixed4(acc * _Color.rgb, _Color.a);
				return c + c;
			}
			ENDCG
		}
	}
}
