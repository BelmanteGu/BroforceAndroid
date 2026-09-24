// Rewrite of the game's "Custom/BurningMasked" for GLES3.
// Two noise textures (uv0, each tiled and scrolled by its _ST) are multiplied (x2) and
// masked by _MainTex.a (sampled with the raw uv1). The saturated result looks up _RampTex,
// times _Color, doubled, drawn additively (Blend One One), no culling.
Shader "Custom/BurningMasked" {
	Properties {
		_Color ("Color", Color) = (0.5,0.5,0.5,0.5)
		_MainTex ("Mask (A, uv2)", 2D) = "white" {}
		_RampTex ("Ramp", 2D) = "white" {}
		_NoiseTex1 ("Noise 1 (A)", 2D) = "white" {}
		_NoiseTex2 ("Noise 2 (A)", 2D) = "white" {}
	}
	SubShader {
		Tags { "Queue"="Transparent+100" }

		Pass {
			Blend One One
			ZTest LEqual
			ZWrite Off
			Cull Off

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"

			sampler2D _MainTex;
			sampler2D _RampTex;
			sampler2D _NoiseTex1;
			float4 _NoiseTex1_ST;
			sampler2D _NoiseTex2;
			float4 _NoiseTex2_ST;
			fixed4 _Color;

			struct appdata {
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
				float2 uv1 : TEXCOORD1;
			};

			struct v2f {
				float4 pos : SV_POSITION;
				float4 uv : TEXCOORD0;      // xy: _MainTex (raw uv1), zw: _NoiseTex1
				float2 uv2 : TEXCOORD1;     // _NoiseTex2
			};

			v2f vert (appdata v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv.xy = v.uv1;
				o.uv.zw = v.uv * _NoiseTex1_ST.xy + frac(_NoiseTex1_ST.zw * _Time.y);
				o.uv2 = v.uv * _NoiseTex2_ST.xy + frac(_NoiseTex2_ST.zw * _Time.y);
				return o;
			}

			fixed4 frag (v2f i) : SV_Target {
				float n = 2 * tex2D(_NoiseTex1, i.uv.zw).a * tex2D(_NoiseTex2, i.uv2).a;
				n = saturate(n * tex2D(_MainTex, i.uv.xy).a);
				fixed4 c = tex2D(_RampTex, float2(n, 0.5)) * _Color;
				return c + c;
			}
			ENDCG
		}
	}
}
