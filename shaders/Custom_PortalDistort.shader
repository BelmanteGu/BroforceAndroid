// Rewrite of the game's "Custom/PortalDistort" for GLES3.
// A GrabPass captures the screen; the second pass samples it offset by
// (_MainTex.rg * 2 - 1) * _DistortStr * _MainTex.b (raw uv), sets alpha *= _MainTex.b and
// multiplies by _Color. Opaque output with depth write.
Shader "Custom/PortalDistort" {
	Properties {
		_Color ("Color", Color) = (1,1,1,1)
		_MainTex ("Distortion (RG), Strength (B)", 2D) = "bump" {}
		_DistortStr ("Distort Strength", Float) = 0.1
	}
	SubShader {
		Tags { "Queue"="Transparent" }

		GrabPass { }

		Pass {
			ZTest LEqual
			ZWrite On
			Cull Back

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"

			sampler2D _MainTex;
			sampler2D _GrabTexture;
			fixed4 _Color;
			float _DistortStr;

			struct appdata {
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f {
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
				float4 grabPos : TEXCOORD1;
			};

			v2f vert (appdata v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				o.grabPos = ComputeGrabScreenPos(o.pos);
				return o;
			}

			fixed4 frag (v2f i) : SV_Target {
				fixed4 t = tex2D(_MainTex, i.uv);
				float2 d = (t.rg * 2 - 1) * _DistortStr * t.b;
				fixed4 c = tex2D(_GrabTexture, (i.grabPos.xy + d) / i.grabPos.w);
				c.a *= t.b;
				return c * _Color;
			}
			ENDCG
		}
	}
}
