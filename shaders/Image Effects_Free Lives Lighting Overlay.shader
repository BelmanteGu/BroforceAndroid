// Rewrite of the game's "Image Effects/Free Lives Lighting Overlay" for GLES3 (full-screen blit).
// Multiplies the screen by the lighting buffer faded towards white by _Intensity:
// out = screen * (_LightingTex.rgb * _Intensity + (1 - _Intensity)), alpha kept from screen.
Shader "Image Effects/Free Lives Lighting Overlay" {
	Properties {
		_LightingTex ("Lighting (RGB)", 2D) = "white" {}
		_Intensity ("Intensity", Float) = 1
		_MainTex ("Base (RGB)", 2D) = "white" {}
	}
	SubShader {
		Pass {
			Blend Off
			ZTest Always
			ZWrite Off
			Cull Off

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"

			sampler2D _MainTex;
			float4 _MainTex_TexelSize;
			sampler2D _LightingTex;
			float _Intensity;

			struct v2f {
				float4 pos : SV_POSITION;
				float4 uv : TEXCOORD0;      // xy: _MainTex, zw: _LightingTex (flipped if needed)
				half bias : TEXCOORD1;
			};

			v2f vert (appdata_img v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv = v.texcoord.xyxy;
				#if UNITY_UV_STARTS_AT_TOP
				if (_MainTex_TexelSize.y < 0)
					o.uv.w = 1 - o.uv.w;
				#endif
				o.bias = 1 - _Intensity;
				return o;
			}

			fixed4 frag (v2f i) : SV_Target {
				half3 light = tex2D(_LightingTex, i.uv.zw).rgb * _Intensity + i.bias;
				return half4(light, 1) * tex2D(_MainTex, i.uv.xy);
			}
			ENDCG
		}
	}
}
