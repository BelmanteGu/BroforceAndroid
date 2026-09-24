// Rewrite of the game's "Custom/DistortedFlagMasked" for GLES3.
// Waving flag: _MainTex2 is sampled through a scrolling _BumpTex distortion and shown
// where _MaskTex.a is set, over the undistorted _ImageTex. Alpha comes from _ImageTex.
Shader "Custom/DistortedFlagMasked" {
	Properties {
		_MainTex2 ("Flag", 2D) = "white" {}
		_BumpTex ("Distortion", 2D) = "bump" {}
		_DistortStr ("Distort Strength", Float) = 0.1
		_ImageTex ("Image", 2D) = "white" {}
		_MaskTex ("Mask", 2D) = "white" {}
	}
	SubShader {
		Tags { "Queue"="Transparent" "IgnoreProjector"="True" }

		Pass {
			Blend SrcAlpha OneMinusSrcAlpha
			ZTest LEqual
			ZWrite On
			Cull Back

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"

			sampler2D _MainTex2, _BumpTex, _ImageTex, _MaskTex;
			float4 _MainTex2_ST, _BumpTex_ST;
			float _DistortStr;

			struct appdata {
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f {
				float4 pos : SV_POSITION;
				float4 uv : TEXCOORD0;    // xy: _MainTex2, zw: _BumpTex (scrolling)
				float2 uvRaw : TEXCOORD1;
			};

			v2f vert (appdata v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv.xy = TRANSFORM_TEX(v.uv, _MainTex2);
				o.uv.zw = v.uv * _BumpTex_ST.xy + _BumpTex_ST.zw * _Time.y;
				o.uvRaw = v.uv;
				return o;
			}

			fixed4 frag (v2f i) : SV_Target {
				float2 bump = tex2D(_BumpTex, i.uv.zw).xy * 2 - 1;
				fixed3 flag = tex2D(_MainTex2, i.uv.xy + bump * _DistortStr).rgb;
				fixed4 img = tex2D(_ImageTex, i.uvRaw);
				fixed mask = tex2D(_MaskTex, i.uvRaw).a;
				return fixed4(lerp(img.rgb, flag, mask), img.a);
			}
			ENDCG
		}
	}
}
