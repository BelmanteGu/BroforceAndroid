// Rewrite of the game's "Custom/ScrollingTextureTransQueue" for GLES3.
// Texture scrolls by _MainTex_ST.zw * time; output = texture * _Color * vertex colour,
// alpha blended, no depth write, back-face culled.
Shader "Custom/ScrollingTextureTransQueue" {
	Properties {
		_Color ("Color", Color) = (1,1,1,1)
		_MainTex ("Base (RGB), Alpha (A)", 2D) = "white" {}
	}
	SubShader {
		Tags { "Queue"="Transparent" }

		Pass {
			Blend SrcAlpha OneMinusSrcAlpha
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
				fixed4 color : COLOR;
			};

			struct v2f {
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
				fixed4 color : COLOR;
			};

			v2f vert (appdata v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv * _MainTex_ST.xy + frac(_MainTex_ST.zw * _Time.y);
				o.color = v.color;
				return o;
			}

			fixed4 frag (v2f i) : SV_Target {
				return tex2D(_MainTex, i.uv) * _Color * i.color;
			}
			ENDCG
		}
	}
}
