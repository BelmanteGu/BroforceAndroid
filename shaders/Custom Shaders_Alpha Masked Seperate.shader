// Rewrite of the game's "Custom Shaders/Alpha Masked Seperate" for GLES3.
// Pixels are discarded wherever any channel of _SliceGuide is below _SliceAmount; the
// rest is _MainTex tinted by _BloodColor, keeping the texture's alpha.
// The original is a Lambert surface shader whose forward base pass outputs
// albedo * (1 + lighting); rendered unlit here (albedo only).
Shader "Custom Shaders/Alpha Masked Seperate" {
	Properties {
		_BloodColor ("Blood Color", Color) = (1,1,1,1)
		_MainTex ("Base (RGB) Trans (A)", 2D) = "white" {}
		_SliceGuide ("Slice Guide (RGB)", 2D) = "white" {}
		_SliceAmount ("Slice Amount", Range(0, 1)) = 0.5
	}
	SubShader {
		Tags { "Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent" }

		Pass {
			Blend SrcAlpha OneMinusSrcAlpha
			ZTest LEqual
			ZWrite Off
			Cull Off
			ColorMask RGB
			Lighting Off

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"

			sampler2D _MainTex, _SliceGuide;
			float4 _MainTex_ST, _SliceGuide_ST;
			fixed4 _BloodColor;
			float _SliceAmount;

			struct appdata {
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f {
				float4 pos : SV_POSITION;
				float4 uv : TEXCOORD0;   // xy: _MainTex, zw: _SliceGuide
			};

			v2f vert (appdata v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv.xy = TRANSFORM_TEX(v.uv, _MainTex);
				o.uv.zw = TRANSFORM_TEX(v.uv, _SliceGuide);
				return o;
			}

			fixed4 frag (v2f i) : SV_Target {
				clip(tex2D(_SliceGuide, i.uv.zw).rgb - _SliceAmount);
				fixed4 c = tex2D(_MainTex, i.uv.xy);
				c.rgb *= _BloodColor.rgb;
				return c;
			}
			ENDCG
		}
	}
}
