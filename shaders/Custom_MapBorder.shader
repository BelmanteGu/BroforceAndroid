// Rewrite of the game's "Custom/MapBorder" for GLES3.
// Texture scrolled by _MainTex_ST.zw * time, multiplied by _Color, drawn additively
// (Blend One One), no depth write.
Shader "Custom/MapBorder" {
	Properties {
		_Color ("Color", Color) = (1,1,1,1)
		_MainTex ("Base (RGB)", 2D) = "white" {}
	}
	SubShader {
		Tags { "Queue"="Transparent-10" }

		Pass {
			Blend One One
			ZTest LEqual
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
				o.uv = v.uv * _MainTex_ST.xy + _MainTex_ST.zw * _Time.y;
				return o;
			}

			fixed4 frag (v2f i) : SV_Target {
				return tex2D(_MainTex, i.uv) * _Color;
			}
			ENDCG
		}
	}
}
