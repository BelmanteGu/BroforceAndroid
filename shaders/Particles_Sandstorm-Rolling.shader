// Rewrite of the game's "Particles/Sandstorm-Rolling" for GLES3.
// Particle uv (TEXCOORD0.xy) is twisted by uv.y * _UvTwist, offset by the custom stream
// TEXCOORD0.zw and scrolled by _MainTex_ST.zw * time. Texture red, faded at the left,
// right and top edges, plus vertex alpha and _AlphaClip drives an alpha test; colour is
// lerp(_Color, _Color2, red) * vertex colour. Opaque cutout, depth write on.
Shader "Particles/Sandstorm-Rolling" {
	Properties {
		_MainTex ("Texture", 2D) = "white" {}
		_Color ("Color", Color) = (1,1,1,1)
		_Color2 ("Color 2", Color) = (1,1,1,1)
		_LeftOpacity ("Left Opacity", Range(0,1)) = 0
		_RightOpacity ("Right Opacity", Range(0,1)) = 0
		_TopOpacity ("Top Opacity", Range(0,1)) = 0
		_UvTwist ("UV Twist", Float) = 0
		_AlphaClip ("Alpha Clip", Range(0,1)) = 0
	}
	SubShader {
		Tags { "Queue"="AlphaTest" }

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
			float4 _MainTex_ST;
			float _UvTwist;
			fixed4 _Color, _Color2;
			float _LeftOpacity, _RightOpacity, _TopOpacity, _AlphaClip;

			struct appdata {
				float4 vertex : POSITION;
				float4 uv : TEXCOORD0;      // xy: quad uv, zw: custom offset stream
				fixed4 color : COLOR;
			};

			struct v2f {
				float4 pos : SV_POSITION;
				float4 uv : TEXCOORD0;      // xy: scrolled texture uv, zw: raw quad uv
				fixed4 color : COLOR;
			};

			v2f vert (appdata v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				float2 uv = v.uv.xy + float2(v.uv.y * _UvTwist, 0) + v.uv.zw;
				o.uv.xy = uv * _MainTex_ST.xy + frac(_MainTex_ST.zw * _Time.y);
				o.uv.zw = v.uv.xy;
				o.color = v.color;
				return o;
			}

			fixed4 frag (v2f i) : SV_Target {
				fixed4 tex = tex2D(_MainTex, i.uv.xy);
				float left = lerp(_LeftOpacity, 1, saturate(i.uv.z * 2));
				float right = lerp(_RightOpacity, 1, saturate((1 - i.uv.z) * 2));
				float top = lerp(_TopOpacity, 1, saturate((1 - i.uv.w) * 16));
				clip(left * tex.r * right * top + i.color.a + _AlphaClip - 1);
				fixed4 c = lerp(_Color, _Color2, tex.r);
				c.rgb *= i.color.rgb;
				return c;
			}
			ENDCG
		}
	}
}
