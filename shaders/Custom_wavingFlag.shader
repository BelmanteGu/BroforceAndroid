// Rewrite of the game's "Custom/wavingFlag" for GLES3.
// Vertex: object x and z are offset by sin(uv.x * P.x + P.y * _Time.y) * P.z * uv.x, using
// _FlagParams for x and _FlagParams2 for z (so the pole edge at uv.x = 0 stays fixed).
// Pixel: plain opaque _MainTex with fog, double sided. Pass 2 casts the waving shadow.
Shader "Custom/wavingFlag" {
	Properties {
		_MainTex ("Base (RGB)", 2D) = "white" {}
		_FlagParams ("Flag Params X (freq, speed, amp)", Vector) = (5,2,0.1,0)
		_FlagParams2 ("Flag Params Z (freq, speed, amp)", Vector) = (3,1.5,0.1,0)
	}
	SubShader {
		Tags { "RenderType"="Opaque" }

		CGINCLUDE
		#include "UnityCG.cginc"

		float4 _FlagParams;
		float4 _FlagParams2;

		float4 WaveVertex (float4 vertex, float u) {
			vertex.x += sin(u * _FlagParams.x + _FlagParams.y * _Time.y) * _FlagParams.z * u;
			vertex.z += sin(u * _FlagParams2.x + _FlagParams2.y * _Time.y) * _FlagParams2.z * u;
			return vertex;
		}
		ENDCG

		Pass {
			ZTest LEqual
			ZWrite On
			Cull Off

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_fog

			sampler2D _MainTex;

			struct appdata {
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f {
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
				UNITY_FOG_COORDS(1)
			};

			v2f vert (appdata v) {
				v2f o;
				o.pos = UnityObjectToClipPos(WaveVertex(float4(v.vertex.xyz, 1), v.uv.x));
				// NOTE: the original uses the raw uv (no _MainTex_ST tiling/offset).
				o.uv = v.uv;
				UNITY_TRANSFER_FOG(o, o.pos);
				return o;
			}

			fixed4 frag (v2f i) : SV_Target {
				fixed4 c = tex2D(_MainTex, i.uv);
				UNITY_APPLY_FOG(i.fogCoord, c);
				return c;
			}
			ENDCG
		}

		Pass {
			Tags { "LightMode"="ShadowCaster" }
			ZTest Less
			ZWrite On
			Cull Off

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_shadowcaster

			struct appdata {
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f {
				float4 pos : SV_POSITION;
			};

			v2f vert (appdata v) {
				v2f o;
				// NOTE: only the directional/spot (linear bias) path is reproduced; point-light
				// cube shadows are not needed on the Android port.
				o.pos = UnityObjectToClipPos(WaveVertex(float4(v.vertex.xyz, 1), v.uv.x));
				o.pos = UnityApplyLinearShadowBias(o.pos);
				return o;
			}

			fixed4 frag (v2f i) : SV_Target {
				return 0;
			}
			ENDCG
		}
	}
}
