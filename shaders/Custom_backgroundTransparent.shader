// Rewrite of the game's "Custom/backgroundTransparent" for GLES3.
// Texture * _Color, alpha blended in the Background queue with the depth test disabled
// (ZTest Always) and no depth write.
Shader "Custom/backgroundTransparent" {
	Properties {
		_Color ("Color", Color) = (1,1,1,1)
		_MainTex ("Base (RGB), Alpha (A)", 2D) = "white" {}
	}
	SubShader {
		Tags { "Queue"="Background" }

		Pass {
			Blend SrcAlpha OneMinusSrcAlpha
			ZTest Always
			ZWrite Off
			Cull Back

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"

			sampler2D _MainTex;
			float4 _MainTex_ST;
			fixed4 _Color;

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
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				return o;
			}

			fixed4 frag (v2f i) : SV_Target {
				return tex2D(_MainTex, i.uv) * _Color;
			}
			ENDCG
		}
	}
}
