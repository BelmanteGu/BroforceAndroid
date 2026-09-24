// Rewrite of the game's "Blend 2 Textures" for GLES3.
// Same name and properties as the original, so existing materials pick it up.
// Output = lerp(_MainTex, _BlendTex, _BlendAmount), alpha tested at 0.9, alpha blended,
// depth write on, no culling, RGB-only colour writes.
Shader "Blend 2 Textures" {
	Properties {
		_BlendAmount ("Blend Amount", Range(0,1)) = 0.5
		_MainTex ("Texture 1", 2D) = "white" {}
		_BlendTex ("Texture 2", 2D) = "white" {}
	}
	SubShader {
		Tags { "Queue"="Transparent" }

		Pass {
			Blend SrcAlpha OneMinusSrcAlpha
			ZTest Less
			ZWrite On
			Cull Off
			ColorMask RGB
			Lighting Off

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"

			sampler2D _MainTex;
			float4 _MainTex_ST;
			sampler2D _BlendTex;
			float4 _BlendTex_ST;
			float _BlendAmount;

			struct appdata {
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f {
				float4 uv : TEXCOORD0;      // xy: _MainTex, zw: _BlendTex
				float4 pos : SV_POSITION;
			};

			v2f vert (appdata v) {
				v2f o;
				o.uv.xy = TRANSFORM_TEX(v.uv, _MainTex);
				o.uv.zw = TRANSFORM_TEX(v.uv, _BlendTex);
				o.pos = UnityObjectToClipPos(v.vertex);
				return o;
			}

			fixed4 frag (v2f i) : SV_Target {
				fixed4 c = lerp(tex2D(_MainTex, i.uv.xy), tex2D(_BlendTex, i.uv.zw), _BlendAmount);
				clip(c.a - 0.9001);
				return c;
			}
			ENDCG
		}
	}
}
