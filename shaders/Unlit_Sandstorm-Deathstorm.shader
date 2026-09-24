// Rewrite of the game's "Unlit/Sandstorm-Deathstorm" for GLES3.
// Like Sandstorm-Foreground: two world-space _SandTex samples, scrolled, wobbled by
// _DistortTex and snapped to _WorldToPixel. alpha = (pow(d, _MaskPow) + _OpacityAdd) *
// _MaskMultiplier times the _MainTex alpha (mesh uv with _MainTex_ST, also wobbled).
// Colour = lerp(_Color2, _Color1, d*d). Alpha blended, no depth write.
Shader "Unlit/Sandstorm-Deathstorm" {
	Properties {
		_OpacityMul ("Opacity Multiplier", Range(0,1)) = 1
		_OpacityAdd ("Opacity Add", Range(0,1)) = 0
		_MainTex ("Mask (A)", 2D) = "white" {}
		_SandTex ("Sand Texture", 2D) = "white" {}
		_SandBoost ("Sand Boost", Float) = 1
		_DistortTex ("Distort Texture", 2D) = "gray" {}
		_DistortStrength ("Distort Strength", Float) = 0.1
		_Color1 ("Color 1", Color) = (1,1,1,1)
		_Color2 ("Color 2", Color) = (0,0,0,1)
		_WorldToPixel ("World To Pixel", Float) = 1
		_MaskPow ("Mask Power", Float) = 1
		_MaskMultiplier ("Mask Multiplier", Float) = 1
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
			sampler2D _SandTex;
			float4 _SandTex_ST;
			sampler2D _DistortTex;
			float4 _DistortTex_ST;
			float _OpacityMul, _OpacityAdd, _SandBoost, _DistortStrength, _WorldToPixel, _MaskPow, _MaskMultiplier;
			fixed4 _Color1, _Color2;

			struct appdata {
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f {
				float4 pos : SV_POSITION;
				float4 sandUV : TEXCOORD0;  // xy: world * _SandTex_ST.x, zw: world * _SandTex_ST.y
				float4 uv : TEXCOORD1;      // xy: _DistortTex (world), zw: _MainTex
			};

			v2f vert (appdata v) {
				v2f o;
				float2 world = mul(unity_ObjectToWorld, v.vertex).xy;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.sandUV = world.xyxy * _SandTex_ST.xxyy;
				o.uv.xy = world * _DistortTex_ST.xy + frac(_DistortTex_ST.zw * _Time.y);
				o.uv.zw = TRANSFORM_TEX(v.uv, _MainTex);
				return o;
			}

			fixed4 frag (v2f i) : SV_Target {
				float2 d = tex2D(_DistortTex, i.uv.xy).xy - 0.5;
				fixed mask = tex2D(_MainTex, i.uv.zw + d * _DistortStrength).a;
				float4 offset = frac(_SandTex_ST.zwzw * _Time.y) + d.xyxy * _DistortStrength;
				offset = floor(offset * _WorldToPixel) / _WorldToPixel;
				float4 sandUV = floor((offset + i.sandUV) * _WorldToPixel) / _WorldToPixel;
				float sand = tex2D(_SandTex, sandUV.xy).x * tex2D(_SandTex, sandUV.zw).x;
				sand = saturate(sand * _SandBoost) * _OpacityMul;
				float alpha = saturate((pow(sand, _MaskPow) + _OpacityAdd) * _MaskMultiplier);
				fixed4 c;
				c.rgb = lerp(_Color2.rgb, _Color1.rgb, sand * sand);
				c.a = mask * alpha;
				return c;
			}
			ENDCG
		}
	}
}
