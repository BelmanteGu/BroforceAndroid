// Rewrite of the game's "Custom/ScrollingTexture" for GLES3.
// Both _MainTex and _BumpTex scroll by their _ST.zw * time; the normal map offsets the
// main texture uv by (n.xy*2-1) * _DistortStr. Output = texture * _Color * vertex colour,
// alpha blended, with Unity fog.
Shader "Custom/ScrollingTexture" {
	Properties {
		_Color ("Color", Color) = (1,1,1,1)
		_MainTex ("Base (RGB), Alpha (A)", 2D) = "white" {}
		_BumpTex ("Distortion (Normal)", 2D) = "bump" {}
		_DistortStr ("Distort Strength", Float) = 0
	}
	SubShader {
		Tags { "Queue"="Transparent-15" }

		Pass {
			Blend SrcAlpha OneMinusSrcAlpha
			ZTest LEqual
			ZWrite Off
			Cull Back

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_fog
			#include "UnityCG.cginc"

			sampler2D _MainTex;
			float4 _MainTex_ST;
			sampler2D _BumpTex;
			float4 _BumpTex_ST;
			fixed4 _Color;
			float _DistortStr;

			struct appdata {
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
				fixed4 color : COLOR;
			};

			struct v2f {
				float4 pos : SV_POSITION;
				float4 uv : TEXCOORD0;      // xy: _MainTex, zw: _BumpTex
				fixed4 color : COLOR;
				UNITY_FOG_COORDS(1)
			};

			v2f vert (appdata v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv.xy = v.uv * _MainTex_ST.xy + frac(_MainTex_ST.zw * _Time.y);
				o.uv.zw = v.uv * _BumpTex_ST.xy + frac(_BumpTex_ST.zw * _Time.y);
				o.color = v.color;
				UNITY_TRANSFER_FOG(o, o.pos);
				return o;
			}

			fixed4 frag (v2f i) : SV_Target {
				float2 offset = tex2D(_BumpTex, i.uv.zw).xy * 2 - 1;
				fixed4 c = tex2D(_MainTex, i.uv.xy + offset * _DistortStr) * _Color * i.color;
				UNITY_APPLY_FOG(i.fogCoord, c);
				return c;
			}
			ENDCG
		}
	}
}
