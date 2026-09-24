// Rewrite of the game's "Unlit/FluidDisplay" for GLES3 (screen-space fluid render texture).
// _MainTex is sampled in screen space, snapped to a _WorldToPixel grid anchored on the object
// origin (aspect-corrected with _MainTex_TexelSize). Discard where r + g < _Cutoff; colour is
// _Color where r >= _Stroke, else _StrokeColor; alpha = texture alpha. Opaque, depth write on.
Shader "Unlit/FluidDisplay" {
	Properties {
		_MainTex ("Fluid Texture", 2D) = "black" {}
		_Color ("Color", Color) = (1,1,1,1)
		_Cutoff ("Cutoff", Range(0, 2)) = 0.5
		_Stroke ("Stroke", Range(0, 1)) = 0.5
		_StrokeColor ("Stroke Color", Color) = (0,0,0,1)
		_WorldToPixel ("World To Pixel", Float) = 1
	}
	SubShader {
		Tags { "Queue"="Transparent" }

		Pass {
			ZTest LEqual
			ZWrite On
			Cull Back

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"

			sampler2D _MainTex;
			float4 _MainTex_TexelSize;
			float _Cutoff;
			fixed4 _Color;
			float _Stroke;
			fixed4 _StrokeColor;
			float _WorldToPixel;

			struct appdata {
				float4 vertex : POSITION;
			};

			struct v2f {
				float4 pos : SV_POSITION;
				float4 screenPos : TEXCOORD0;
				float2 origin : TEXCOORD1;
			};

			v2f vert (appdata v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.screenPos = ComputeScreenPos(o.pos);
				o.origin = float2(unity_ObjectToWorld[0].w, unity_ObjectToWorld[1].w);
				return o;
			}

			// Sign-preserving fractional part (HLSL fmod(x, 1)).
			float2 SignedFrac (float2 x) {
				return frac(abs(x)) * sign(x);
			}

			fixed4 frag (v2f i) : SV_Target {
				float2 suv = i.screenPos.xy / i.screenPos.w;
				float aspect = _MainTex_TexelSize.x * _MainTex_TexelSize.w;   // height / width
				float2 o = SignedFrac(float2(aspect, 1) * i.origin / _WorldToPixel);
				float2 p = suv + o;
				p.x /= aspect;
				p = floor(p * _WorldToPixel) / _WorldToPixel;
				p.x *= aspect;
				fixed4 t = tex2D(_MainTex, p - o);
				clip(t.r + t.g - _Cutoff);
				fixed3 c = (t.r >= _Stroke) ? _Color.rgb : _StrokeColor.rgb;
				return fixed4(c, t.a);
			}
			ENDCG
		}
	}
}
