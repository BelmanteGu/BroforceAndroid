// Rewrite of the game's "Unlit/Depth Cutout With ColouredImage No Fog" for GLES3.
// Same name and properties as the original, so existing materials pick it up.
// Vertex colour * _TintColor * texture, alpha test at 0.025, output doubled (so the
// default 0.5 grey tint is neutral), alpha blended, depth write on, RGB-only writes.
Shader "Unlit/Depth Cutout With ColouredImage No Fog" {
	Properties {
		_MainTex ("Base (RGB), Alpha (A)", 2D) = "white" {}
		_TintColor ("Tint Color", Color) = (0.5,0.5,0.5,0.5)
	}
	SubShader {
		Tags { "Queue"="Background" "IgnoreProjector"="True" }
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
			fixed4 _TintColor;

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
				fixed4 c = i.color * _TintColor * tex2D(_MainTex, i.uv);
				clip(c.a - 0.0251);
				return c + c;
			}
			ENDCG
		}
	}
}
