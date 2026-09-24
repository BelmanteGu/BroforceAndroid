// Rewrite of the game's "Custom/ScrollingTendrils2" for GLES3.
// Same inputs as ScrollingTendrils (textures scroll by frac(_ST.zw * time), mask on uv2,
// _BumpTex distortion), but v = _MainTex.r * _MaskTex.a is levelled first:
// out = saturate(float4((v - _Black) / (_White - _Black) as grey, v)) * _Color.
Shader "Custom/ScrollingTendrils2" {
	Properties {
		_Color ("Color", Color) = (1,1,1,1)
		_MainTex ("Tendrils (R), offset = scroll speed", 2D) = "white" {}
		_BumpTex ("Distortion (RG), offset = scroll speed", 2D) = "bump" {}
		_MaskTex ("Mask (A, uv2), offset = scroll speed", 2D) = "white" {}
		_DistortStr ("Distort Strength", Float) = 0.05
		_White ("White Point", Float) = 1
		_Black ("Black Point", Float) = 0
	}
	SubShader {
		Tags { "Queue"="Transparent-10" "IgnoreProjector"="True" "RenderType"="Transparent" }

		Pass {
			Blend SrcAlpha OneMinusSrcAlpha
			ZTest LEqual
			ZWrite Off
			Cull Off

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"

			sampler2D _MainTex;
			sampler2D _BumpTex;
			sampler2D _MaskTex;
			float4 _MainTex_ST;
			float4 _BumpTex_ST;
			float4 _MaskTex_ST;
			fixed4 _Color;
			float _DistortStr;
			float _White;
			float _Black;

			struct appdata {
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
				float2 uv1 : TEXCOORD1;
			};

			struct v2f {
				float4 pos : SV_POSITION;
				float4 uv : TEXCOORD0;      // xy: _MainTex, zw: _BumpTex
				float2 uvMask : TEXCOORD1;
			};

			v2f vert (appdata v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv.xy = v.uv * _MainTex_ST.xy + frac(_MainTex_ST.zw * _Time.y);
				o.uv.zw = v.uv * _BumpTex_ST.xy + frac(_BumpTex_ST.zw * _Time.y);
				o.uvMask = v.uv1 * _MaskTex_ST.xy + frac(_MaskTex_ST.zw * _Time.y);
				return o;
			}

			fixed4 frag (v2f i) : SV_Target {
				float2 d = (tex2D(_BumpTex, i.uv.zw).xy * 2 - 1) * _DistortStr;
				float m = tex2D(_MainTex, i.uv.xy + d).r;
				float mask = tex2D(_MaskTex, i.uvMask + float2(d.x, 0)).a;
				float v = m * mask;
				float grey = (v - _Black) / (_White - _Black);
				return saturate(float4(grey, grey, grey, v)) * _Color;
			}
			ENDCG
		}
	}
}
