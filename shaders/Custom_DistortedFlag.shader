// Rewrite of the game's "Custom/DistortedFlag" for GLES3.
// A normal map (_BumpTex, tiled by its _ST and scrolled by _BumpTex_ST.zw * time) offsets
// the raw mesh uv of _MainTex by (n.xy*2-1) * _DistortStr. Opaque, depth write on.
// _MainTex tiling/offset is ignored, as in the original.
Shader "Custom/DistortedFlag" {
	Properties {
		_MainTex ("Base (RGB)", 2D) = "white" {}
		_BumpTex ("Distortion (Normal)", 2D) = "bump" {}
		_DistortStr ("Distort Strength", Float) = 0.02
	}
	SubShader {
		Tags { "Queue"="Geometry" }

		Pass {
			Blend Off
			ZTest LEqual
			ZWrite On
			Cull Back

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"

			sampler2D _MainTex;
			sampler2D _BumpTex;
			float4 _BumpTex_ST;
			float _DistortStr;

			struct appdata {
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f {
				float4 pos : SV_POSITION;
				float4 uv : TEXCOORD0;      // xy: _MainTex (raw), zw: _BumpTex (scrolling)
			};

			v2f vert (appdata v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv.xy = v.uv;
				o.uv.zw = v.uv * _BumpTex_ST.xy + _BumpTex_ST.zw * _Time.y;
				return o;
			}

			fixed4 frag (v2f i) : SV_Target {
				float2 offset = tex2D(_BumpTex, i.uv.zw).xy * 2 - 1;
				return tex2D(_MainTex, i.uv.xy + offset * _DistortStr);
			}
			ENDCG
		}
	}
}
