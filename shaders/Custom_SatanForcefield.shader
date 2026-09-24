// Rewrite of the game's "Custom/SatanForcefield" for GLES3.
// _BumpTex perturbs the world normal (fresnel vs view (0,0,-1), raised to _FresPow, looked up in
// _FresTex) and the uvs of _MainTex / _MaskTex (uv2). m = saturate(main.a * mask.r + mask.g) lerps
// the fresnel colour towards black with alpha mask.r * m; then rgb lerps to _Color by _Color.a.
Shader "Custom/SatanForcefield" {
	Properties {
		_Color ("Color (A = amount)", Color) = (1,1,1,0)
		_MainTex ("Pattern (A), offset = scroll speed", 2D) = "white" {}
		_MaskTex ("Mask (RG, uv2), offset = scroll speed", 2D) = "white" {}
		_BumpTex ("Distortion (RG), offset = scroll speed", 2D) = "bump" {}
		_BumpStr ("Bump Strength", Float) = 0.1
		_FresTex ("Fresnel Ramp", 2D) = "white" {}
		_FresPow ("Fresnel Power", Float) = 1
		_Alpha ("Alpha", Range(0, 1)) = 1
	}
	SubShader {
		Tags { "Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent" }

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
			sampler2D _MaskTex;
			sampler2D _BumpTex;
			sampler2D _FresTex;
			float4 _MainTex_ST;
			float4 _BumpTex_ST;
			float4 _MaskTex_ST;
			fixed4 _Color;
			float _BumpStr;
			float _FresPow;
			float _Alpha;

			struct appdata {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float2 uv : TEXCOORD0;
				float2 uv1 : TEXCOORD1;
			};

			struct v2f {
				float4 pos : SV_POSITION;
				float4 uv : TEXCOORD0;      // xy: _MainTex, zw: _BumpTex
				float3 normal : TEXCOORD1;
				float2 uvMask : TEXCOORD2;
			};

			v2f vert (appdata v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv.xy = v.uv * _MainTex_ST.xy + _MainTex_ST.zw * _Time.y;
				o.uv.zw = v.uv * _BumpTex_ST.xy + _BumpTex_ST.zw * _Time.y;
				o.uvMask = v.uv1 * _MaskTex_ST.xy + _MaskTex_ST.zw * _Time.y;
				o.normal = normalize(mul((float3x3)unity_ObjectToWorld, v.normal));
				return o;
			}

			fixed4 frag (v2f i) : SV_Target {
				float2 d = (tex2D(_BumpTex, i.uv.zw).xy * 2 - 1) * _BumpStr;
				float3 n = normalize(float3(i.normal.xy + d, i.normal.z));
				float f = pow(abs(dot(n, float3(0, 0, -1))), _FresPow);
				float4 fres = tex2D(_FresTex, float2(f, 0.5));
				float mainA = tex2D(_MainTex, i.uv.xy + d).a;
				float2 mask = tex2D(_MaskTex, i.uvMask + d).rg;
				float m = saturate(mainA * mask.r + mask.g);
				float4 c = lerp(fres, float4(0, 0, 0, mask.r * m), m);
				c.rgb = lerp(c.rgb, _Color.rgb, _Color.a);
				c.a *= _Alpha;
				return c;
			}
			ENDCG
		}
	}
}
