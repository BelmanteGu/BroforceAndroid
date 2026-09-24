// Rewrite of the game's "Custom/DistortedFlagUI" for GLES3.
// _BumpTex (tiled by its _ST.xy, scrolled by _ST.zw * time) offsets the raw uv of _MainTex by
// (bump.xy * 2 - 1) * _DistortStr; rgb is multiplied by _ScrollTex (tiled, scrolled by
// frac(_ST.zw * time)). Alpha = _MainTex.a. UI stencil/colour-mask properties are kept.
Shader "Custom/DistortedFlagUI" {
	Properties {
		_MainTex ("Base (RGB), Alpha (A)", 2D) = "white" {}
		_BumpTex ("Distortion (RG), offset = scroll speed", 2D) = "bump" {}
		_DistortStr ("Distort Strength", Float) = 0.05
		_ScrollTex ("Scroll Tex (RGB), offset = scroll speed", 2D) = "white" {}

		_StencilComp ("Stencil Comparison", Float) = 8
		_Stencil ("Stencil ID", Float) = 0
		_StencilOp ("Stencil Operation", Float) = 0
		_StencilWriteMask ("Stencil Write Mask", Float) = 255
		_StencilReadMask ("Stencil Read Mask", Float) = 255
		_ColorMask ("Color Mask", Float) = 15
	}
	SubShader {
		Tags { "Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent" "PreviewType"="Plane" "CanUseSpriteAtlas"="True" }

		Stencil {
			Ref [_Stencil]
			Comp [_StencilComp]
			Pass [_StencilOp]
			ReadMask [_StencilReadMask]
			WriteMask [_StencilWriteMask]
		}

		Pass {
			Blend SrcAlpha OneMinusSrcAlpha
			// NOTE: the reference reports ZTest "Disabled" and ColorMask 0, which are the
			// unresolved values of property-driven state; the standard UI bindings are used.
			ZTest [unity_GUIZTestMode]
			ZWrite Off
			Cull Off
			ColorMask [_ColorMask]

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"

			sampler2D _MainTex;
			sampler2D _BumpTex;
			sampler2D _ScrollTex;
			float4 _BumpTex_ST;
			float4 _ScrollTex_ST;
			float _DistortStr;

			struct appdata {
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f {
				float4 pos : SV_POSITION;
				float4 uv : TEXCOORD0;      // xy: _MainTex (raw uv), zw: _BumpTex
				float2 uvScroll : TEXCOORD1;
			};

			v2f vert (appdata v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv.xy = v.uv;
				o.uv.zw = v.uv * _BumpTex_ST.xy + _BumpTex_ST.zw * _Time.y;
				o.uvScroll = v.uv * _ScrollTex_ST.xy + frac(_ScrollTex_ST.zw * _Time.y);
				return o;
			}

			fixed4 frag (v2f i) : SV_Target {
				float2 bump = tex2D(_BumpTex, i.uv.zw).xy * 2 - 1;
				fixed4 c = tex2D(_MainTex, i.uv.xy + bump * _DistortStr);
				fixed3 s = tex2D(_ScrollTex, i.uvScroll).rgb;
				return fixed4(c.rgb * s, c.a);
			}
			ENDCG
		}
	}
}
