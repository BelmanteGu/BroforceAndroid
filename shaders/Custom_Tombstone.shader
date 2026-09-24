// Rewrite of the game's "Custom/Tombstone" for GLES3.
// Blends _MainTex towards _PeeTex by _TombstoneMask.a * _DrawMask.a (all sampled with the
// raw mesh uv, no tiling/offset), alpha blended, no depth write.
Shader "Custom/Tombstone" {
	Properties {
		_MainTex ("Base (RGB), Alpha (A)", 2D) = "white" {}
		_PeeTex ("Pee Texture", 2D) = "white" {}
		_TombstoneMask ("Tombstone Mask", 2D) = "white" {}
		_DrawMask ("Draw Mask", 2D) = "black" {}
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
			sampler2D _PeeTex;
			sampler2D _TombstoneMask;
			sampler2D _DrawMask;

			struct appdata {
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f {
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
			};

			v2f vert (appdata v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				return o;
			}

			fixed4 frag (v2f i) : SV_Target {
				fixed mask = tex2D(_TombstoneMask, i.uv).a * tex2D(_DrawMask, i.uv).a;
				return lerp(tex2D(_MainTex, i.uv), tex2D(_PeeTex, i.uv), mask);
			}
			ENDCG
		}
	}
}
