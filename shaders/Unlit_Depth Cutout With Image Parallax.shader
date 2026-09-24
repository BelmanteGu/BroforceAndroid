// Rewrite of the game's "Unlit/Depth Cutout With Image Parallax" for GLES3.
// Identical to "Unlit/Depth Cutout With Image" (texture * vertex colour, alpha test
// at 0.2) but drawn one step earlier in the Background queue, behind the level.
Shader "Unlit/Depth Cutout With Image Parallax" {
	Properties {
		_MainTex ("Base (RGB), Alpha (A)", 2D) = "white" {}
	}
	SubShader {
		Tags { "Queue"="Background-1" "IgnoreProjector"="True" }
		LOD 100

		Pass {
			Blend SrcAlpha OneMinusSrcAlpha
			ZTest Less
			ZWrite On
			Cull Off
			ColorMask RGB
			Lighting Off

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"

			sampler2D _MainTex;
			float4 _MainTex_ST;

			struct appdata {
				float4 vertex : POSITION;
				fixed4 color : COLOR;
				float2 uv : TEXCOORD0;
			};

			struct v2f {
				fixed4 color : COLOR;
				float2 uv : TEXCOORD0;
				float4 pos : SV_POSITION;
			};

			v2f vert (appdata v) {
				v2f o;
				o.color = saturate(v.color);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				o.pos = UnityObjectToClipPos(v.vertex);
				return o;
			}

			fixed4 frag (v2f i) : SV_Target {
				fixed4 c = tex2D(_MainTex, i.uv) * i.color;
				clip(c.a - 0.2001);
				return c;
			}
			ENDCG
		}
	}
}
