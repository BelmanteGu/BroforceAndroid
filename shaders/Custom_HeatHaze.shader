// Rewrite of the game's "Custom/HeatHaze" for GLES3.
// Grabs the screen, then re-samples it offset by a scrolling normal map (_BumpTex,
// offset = _BumpTex_ST.zw * time) scaled by vertex alpha * _DistortStr. Opaque output.
// _Color is kept for material compatibility but unused, as in the original.
Shader "Custom/HeatHaze" {
	Properties {
		_Color ("Color", Color) = (1,1,1,1)
		_BumpTex ("Distortion (Normal)", 2D) = "bump" {}
		_DistortStr ("Distort Strength", Float) = 0.01
	}
	SubShader {
		Tags { "Queue"="Geometry" }

		GrabPass { }

		Pass {
			Blend Off
			ZTest LEqual
			ZWrite Off
			Cull Off

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"

			sampler2D _BumpTex;
			float4 _BumpTex_ST;
			float _DistortStr;
			sampler2D _GrabTexture;

			struct appdata {
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
				fixed4 color : COLOR;
			};

			struct v2f {
				float4 pos : SV_POSITION;
				float4 grab : TEXCOORD0;
				float2 uv : TEXCOORD1;
				float strength : TEXCOORD2;
			};

			v2f vert (appdata v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.grab = ComputeGrabScreenPos(o.pos);
				o.uv = v.uv * _BumpTex_ST.xy + frac(_BumpTex_ST.zw * _Time.y);
				o.strength = v.color.a * _DistortStr;
				return o;
			}

			fixed4 frag (v2f i) : SV_Target {
				float2 offset = tex2D(_BumpTex, i.uv).xy * 2 - 1;
				// NOTE: the original does not divide by w (fine for the ortho game camera);
				// dividing here gives the same result for ortho and is correct for perspective.
				float2 uv = i.grab.xy / i.grab.w + offset * i.strength;
				return tex2D(_GrabTexture, uv);
			}
			ENDCG
		}
	}
}
