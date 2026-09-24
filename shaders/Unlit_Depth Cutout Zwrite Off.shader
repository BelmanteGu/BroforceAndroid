// Rewrite of the game's "Unlit/Depth Cutout Zwrite Off" for GLES3.
// Same name and properties as the original, so existing materials pick it up.
// Behavior matched to the original pass: texture * vertex colour, discarded where alpha <= 0.2,
// alpha blended, no depth write, no culling, RGB-only colour writes, with fog.
Shader "Unlit/Depth Cutout Zwrite Off" {
	Properties {
		_MainTex ("Base (RGB), Alpha (A)", 2D) = "white" {}
	}
	SubShader {
		Tags { "Queue"="Background" "IgnoreProjector"="True" }
		LOD 100

		Pass {
			Blend SrcAlpha OneMinusSrcAlpha
			ZTest Less
			ZWrite Off
			Cull Off
			ColorMask RGB
			Lighting Off

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_fog
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
				UNITY_FOG_COORDS(1)
				float4 pos : SV_POSITION;
			};

			v2f vert (appdata v) {
				v2f o;
				o.color = saturate(v.color);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				o.pos = UnityObjectToClipPos(v.vertex);
				UNITY_TRANSFER_FOG(o, o.pos);
				return o;
			}

			fixed4 frag (v2f i) : SV_Target {
				fixed4 c = tex2D(_MainTex, i.uv) * i.color;
				if (c.a <= 0.2) discard;
				UNITY_APPLY_FOG(i.fogCoord, c);
				return c;
			}
			ENDCG
		}
	}
}
