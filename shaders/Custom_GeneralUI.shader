// Rewrite of the game's "Custom/GeneralUI" for GLES3.
// rgb = _MainTex.rgb * _Scanlines.a + _Color.rgb (colour is added, not multiplied),
// alpha = _MainTex.a. _Scanlines uses its tiling (_ST.xy) and scrolls by frac(_ST.zw * time).
// The original lists no stencil properties, so no Stencil block. Alpha blended, no depth write.
Shader "Custom/GeneralUI" {
	Properties {
		_Color ("Color (added)", Color) = (0,0,0,1)
		_MainTex ("Base (RGB), Alpha (A)", 2D) = "white" {}
		_Scanlines ("Scanlines (A), offset = scroll speed", 2D) = "white" {}
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
			sampler2D _Scanlines;
			float4 _Scanlines_ST;
			fixed4 _Color;

			struct appdata {
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f {
				float4 pos : SV_POSITION;
				float4 uv : TEXCOORD0;      // xy: _MainTex (raw uv), zw: _Scanlines
			};

			v2f vert (appdata v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv.xy = v.uv;
				o.uv.zw = v.uv * _Scanlines_ST.xy + frac(_Scanlines_ST.zw * _Time.y);
				return o;
			}

			fixed4 frag (v2f i) : SV_Target {
				fixed scan = tex2D(_Scanlines, i.uv.zw).a;
				fixed4 tex = tex2D(_MainTex, i.uv.xy);
				return fixed4(tex.rgb * scan + _Color.rgb, tex.a);
			}
			ENDCG
		}
	}
}
