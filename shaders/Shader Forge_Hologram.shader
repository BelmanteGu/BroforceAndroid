// Rewrite of the game's "Shader Forge/Hologram" for GLES3.
// Noise (_NoiseTex.a, scrolling up at 0.2 * time) and a blink term (fmod(time * 0.6, 1) >= 0.2)
// cut the sprite out at 0.5; _MainTex is wobbled horizontally by a scanline sine, gated by the
// blink and alpha-pulsed by a fast sine; noise adds _Color * 0.5. Alpha * _Color.a * vertex alpha.
Shader "Shader Forge/Hologram" {
	Properties {
		_Color ("Color", Color) = (0.5,0.8,1,1)
		_MainTex ("MainTex", 2D) = "white" {}
		_NoiseTex ("NoiseTex", 2D) = "white" {}
		_Cutoff ("Alpha cutoff", Range(0, 1)) = 0.5
	}
	SubShader {
		Tags { "Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent" }

		CGINCLUDE
		#include "UnityCG.cginc"

		sampler2D _NoiseTex;
		float4 _NoiseTex_ST;
		float4 _TimeEditor;     // Shader Forge editor time offset (0 at runtime)

		// Shared cutout: returns the blink gate (0 or 1) and discards like the original.
		// NOTE: the original hardcodes 0.5 as the cutoff; _Cutoff is declared but unused.
		float HologramClip (float2 uv, float4 t) {
			float blinkT = t.w * 0.2;
			float blink = (fmod(blinkT, 1.0) >= 0.2) ? 1.0 : 0.0;
			float2 noiseUV = float2(uv.x, uv.y + t.x * 0.2) * _NoiseTex_ST.xy + _NoiseTex_ST.zw;
			float noise = tex2D(_NoiseTex, noiseUV).a;
			clip(max(blink, noise) - 0.5);
			return blink;
		}
		ENDCG

		Pass {
			Tags { "LightMode"="ForwardBase" }
			Blend SrcAlpha OneMinusSrcAlpha
			ZTest LEqual
			ZWrite Off
			Cull Back

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			sampler2D _MainTex;
			float4 _MainTex_ST;
			fixed4 _Color;

			struct appdata {
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
				fixed4 color : COLOR;
			};

			struct v2f {
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
				fixed4 color : COLOR;
			};

			v2f vert (appdata v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				o.color = v.color;
				return o;
			}

			fixed4 frag (v2f i) : SV_Target {
				float4 t = _Time + _TimeEditor;
				float blink = HologramClip(i.uv, t);
				float2 noiseUV = float2(i.uv.x, i.uv.y + t.x * 0.2) * _NoiseTex_ST.xy + _NoiseTex_ST.zw;
				float noise = tex2D(_NoiseTex, noiseUV).a;
				float3 glow = noise * _Color.rgb * 0.5;
				float wobble = sin(i.uv.y * 100 + t.w * 5) * 0.00071;
				float pulse = (sin(t.w * 17.632) + 1) * 0.25 + 0.5;
				float2 uv = float2(i.uv.x + wobble, i.uv.y) * _MainTex_ST.xy + _MainTex_ST.zw;
				fixed4 m = tex2D(_MainTex, uv);
				return fixed4(m.rgb * blink + glow, pulse * m.a * _Color.a * i.color.a);
			}
			ENDCG
		}

		Pass {
			Tags { "LightMode"="ShadowCaster" }
			ZTest LEqual
			ZWrite On
			Cull Back
			Offset 1, 1

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_shadowcaster

			struct appdata {
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f {
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD1;
			};

			v2f vert (appdata v) {
				v2f o;
				o.pos = UnityApplyLinearShadowBias(UnityObjectToClipPos(v.vertex));
				o.uv = v.uv;
				return o;
			}

			fixed4 frag (v2f i) : SV_Target {
				HologramClip(i.uv, _Time + _TimeEditor);
				return 0;
			}
			ENDCG
		}
	}
}
