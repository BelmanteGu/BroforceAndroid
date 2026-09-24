// Rewrite of the game's "Custom/CloudTendrils" for GLES3.
// Pass 1 is a depth-only prepass (vertex colour, ColorMask 0); pass 2 draws with ZTest Equal.
// v = ((1 - pow(saturate(N.(0,0,-1)), _FresPow)) * 2 - 1 + _MainTex.a) * _MaskTex.a * vcol.g,
// colour = lerp(_Color1, _Color2, v) + (_LightTex.a * g * g + 0.5 * g) * _LightAmount; alpha = _Alpha.
Shader "Custom/CloudTendrils" {
	Properties {
		_MainTex ("Cloud (A), offset = scroll speed", 2D) = "white" {}
		_MaskTex ("Mask (A), offset = scroll speed", 2D) = "white" {}
		_BumpTex ("Distortion (RG), offset = scroll speed", 2D) = "bump" {}
		_LightTex ("Light (A)", 2D) = "black" {}
		_LightAmount ("Light Amount", Range(0, 1)) = 0.5
		_DistortStr ("Distort Strength", Float) = 0.05
		_FresPow ("Fresnel Power", Float) = 1
		_Color1 ("Color 1", Color) = (0,0,0,1)
		_Color2 ("Color 2", Color) = (1,1,1,1)
		_Alpha ("Alpha", Range(0, 1)) = 1
	}
	SubShader {
		Tags { "Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent" }

		Pass {
			Blend SrcAlpha OneMinusSrcAlpha
			ZTest LEqual
			ZWrite On
			Cull Off
			ColorMask 0

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"

			struct appdata {
				float4 vertex : POSITION;
				fixed4 color : COLOR;
			};

			struct v2f {
				fixed4 color : COLOR;
				float4 pos : SV_POSITION;
			};

			v2f vert (appdata v) {
				v2f o;
				o.color = saturate(v.color);
				o.pos = UnityObjectToClipPos(v.vertex);
				return o;
			}

			fixed4 frag (v2f i) : SV_Target {
				return i.color;
			}
			ENDCG
		}

		Pass {
			Blend SrcAlpha OneMinusSrcAlpha
			ZTest Equal
			ZWrite Off
			Cull Off

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"

			sampler2D _MainTex;
			sampler2D _MaskTex;
			sampler2D _BumpTex;
			sampler2D _LightTex;
			float4 _MainTex_ST;
			float4 _BumpTex_ST;
			float4 _MaskTex_ST;
			float _LightAmount;
			float _DistortStr;
			float _FresPow;
			fixed4 _Color1;
			fixed4 _Color2;
			float _Alpha;

			struct appdata {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float2 uv : TEXCOORD0;
				fixed4 color : COLOR;
			};

			struct v2f {
				float4 pos : SV_POSITION;
				float4 uv : TEXCOORD0;      // xy: _MainTex, zw: _BumpTex
				float3 normal : TEXCOORD1;
				float2 uvMask : TEXCOORD2;
				fixed4 color : COLOR;
			};

			v2f vert (appdata v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv.xy = v.uv * _MainTex_ST.xy + frac(_MainTex_ST.zw * _Time.y);
				o.uv.zw = v.uv * _BumpTex_ST.xy + frac(_BumpTex_ST.zw * _Time.y);
				// The mask ignores its tiling; only the offset (as scroll speed) is used.
				o.uvMask = v.uv + frac(_MaskTex_ST.zw * _Time.y);
				o.normal = normalize(mul((float3x3)unity_ObjectToWorld, v.normal));
				o.color = v.color;
				return o;
			}

			fixed4 frag (v2f i) : SV_Target {
				float g = i.color.g;
				float fres = pow(saturate(dot(float3(0, 0, -1), normalize(i.normal))), _FresPow);
				fres = (1 - fres) * 2 - 1;
				float2 uv = i.uv.xy + (tex2D(_BumpTex, i.uv.zw).xy * 2 - 1) * _DistortStr;
				float cloud = tex2D(_MainTex, uv).a;
				float light = tex2D(_LightTex, uv).a;
				float mask = tex2D(_MaskTex, i.uvMask).a;
				float v = (fres + cloud) * mask * g;
				float3 c = lerp(_Color1.rgb, _Color2.rgb, v);
				float l = light * g * g + g * 0.5;
				return fixed4(saturate(l * _LightAmount + c), _Alpha);
			}
			ENDCG
		}
	}
}
