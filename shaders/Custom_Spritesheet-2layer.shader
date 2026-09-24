// Rewrite of the game's "Custom/Spritesheet-2layer" for GLES3.
// Two animated frames of the same sheet (_Width x _Height cells) are chosen from time * _Speed
// (second layer shifted by _Offset), added with saturate and multiplied by _Color. Additive blend.
// Frame cell: column = floor(frac(s) * _Frames), row = floor(frac(s / _Height) * _Frames).
Shader "Custom/Spritesheet-2layer" {
	Properties {
		_Color ("Color", Color) = (1,1,1,1)
		_MainTex ("Sprite Sheet", 2D) = "white" {}
		_Frames ("Frames", Float) = 4
		_Speed ("Speed", Float) = 1
		_Width ("Width (cells)", Float) = 4
		_Height ("Height (cells)", Float) = 1
		_Offset ("Layer 2 Offset", Float) = 0.5
	}
	SubShader {
		Tags { "Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent" }

		Pass {
			Blend One One
			ZTest LEqual
			ZWrite Off
			Cull Back

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"

			sampler2D _MainTex;
			fixed4 _Color;
			// The original declares _Frames/_Speed/_Width/_Height as ints (truncated here).
			float _Frames;
			float _Speed;
			float _Width;
			float _Height;
			float _Offset;

			struct appdata {
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f {
				float4 pos : SV_POSITION;
				float4 uv : TEXCOORD0;      // xy: layer 1, zw: layer 2
			};

			float2 FrameUV (float2 uv, float s, float2 invSize, float frames) {
				float2 cell = floor(frac(float2(s, s * invSize.y)) * frames);
				return (cell + uv) * invSize;
			}

			v2f vert (appdata v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				float frames = trunc(_Frames);
				float speed = trunc(_Speed);
				float2 invSize = 1.0 / float2(trunc(_Width), trunc(_Height));
				o.uv.xy = FrameUV(v.uv, speed * _Time.y, invSize, frames);
				o.uv.zw = FrameUV(v.uv, _Time.y * speed + _Offset, invSize, frames);
				return o;
			}

			fixed4 frag (v2f i) : SV_Target {
				fixed4 c = saturate(tex2D(_MainTex, i.uv.xy) + tex2D(_MainTex, i.uv.zw));
				return c * _Color;
			}
			ENDCG
		}
	}
}
