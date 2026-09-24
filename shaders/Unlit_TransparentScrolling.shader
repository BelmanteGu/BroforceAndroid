// Rewrite of the game's "Unlit/TransparentScrolling" for GLES3.
// Plain texture scrolled by _MainTex_ST.zw * time, alpha blended, with depth write on
// and back-face culling, as in the original.
Shader "Unlit/TransparentScrolling" {
	Properties {
		_MainTex ("Base (RGB), Alpha (A)", 2D) = "white" {}
	}
	SubShader {
		Tags { "Queue"="Transparent" }

		Pass {
			Blend SrcAlpha OneMinusSrcAlpha
			ZTest LEqual
			ZWrite On
			Cull Back

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"

			sampler2D _MainTex;
			float4 _MainTex_ST;

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
				o.uv = v.uv * _MainTex_ST.xy + frac(_MainTex_ST.zw * _Time.y);
				return o;
			}

			fixed4 frag (v2f i) : SV_Target {
				return tex2D(_MainTex, i.uv);
			}
			ENDCG
		}
	}
}
