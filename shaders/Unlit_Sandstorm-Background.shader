// Rewrite of the game's "Unlit/Sandstorm-Background" for GLES3.
// _MainTex is sampled in world space (scaled by _MainTex_ST.xy, scrolled by .zw * time),
// wobbled by _DistortTex and snapped to the _WorldToPixel grid. alpha = tex.r * _Opacity,
// colour = lerp(_Color2, _Color1, alpha^2). Alpha blended, no depth write.
Shader "Unlit/Sandstorm-Background" {
	Properties {
		_Opacity ("Opacity", Range(0,1)) = 1
		_MainTex ("Sand Texture", 2D) = "white" {}
		_DistortTex ("Distort Texture", 2D) = "gray" {}
		_DistortStrength ("Distort Strength", Float) = 0.1
		_Color1 ("Color 1", Color) = (1,1,1,1)
		_Color2 ("Color 2", Color) = (0,0,0,1)
		_WorldToPixel ("World To Pixel", Float) = 1
	}
	SubShader {
		Tags { "Queue"="Transparent" }

		Pass {
			Blend SrcAlpha OneMinusSrcAlpha
			ZTest LEqual
			ZWrite Off
			Cull Back

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"

			sampler2D _MainTex;
			float4 _MainTex_ST;
			sampler2D _DistortTex;
			float4 _DistortTex_ST;
			float _Opacity, _DistortStrength, _WorldToPixel;
			fixed4 _Color1, _Color2;

			struct appdata {
				float4 vertex : POSITION;
			};

			struct v2f {
				float4 pos : SV_POSITION;
				float4 uv : TEXCOORD0;      // xy: _MainTex (world), zw: _DistortTex (world, scrolling)
			};

			v2f vert (appdata v) {
				v2f o;
				float2 world = mul(unity_ObjectToWorld, v.vertex).xy;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv.xy = world * _MainTex_ST.xy;
				o.uv.zw = world * _DistortTex_ST.xy + frac(_DistortTex_ST.zw * _Time.y);
				return o;
			}

			fixed4 frag (v2f i) : SV_Target {
				float2 d = tex2D(_DistortTex, i.uv.zw).xy - 0.5;
				float2 offset = frac(_MainTex_ST.zw * _Time.y) + d * _DistortStrength;
				offset = floor(offset * _WorldToPixel) / _WorldToPixel;
				float2 uv = floor((offset + i.uv.xy) * _WorldToPixel) / _WorldToPixel;
				float a = tex2D(_MainTex, uv).x * _Opacity;
				return fixed4(lerp(_Color2.rgb, _Color1.rgb, a * a), a);
			}
			ENDCG
		}
	}
}
