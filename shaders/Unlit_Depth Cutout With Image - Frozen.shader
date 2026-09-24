// Rewrite of the game's "Unlit/Depth Cutout With Image - Frozen" for GLES3.
// "Unlit/Depth Cutout With Image" plus a freeze effect: ice rises from the bottom of the
// sprite (UV1.y) as _Frozen goes 0 -> 1, snapped to the sprite's pixel grid
// (_SpriteSize) with a noisy edge from _NoiseTex. Frozen pixels become luminance +
// _FrozenCol; the one-pixel ice front is brightened towards white.
Shader "Unlit/Depth Cutout With Image - Frozen" {
	Properties {
		_MainTex ("Base (RGB), Alpha (A)", 2D) = "white" {}
		_FrozenCol ("Frozen Color", Color) = (0.3,0.5,0.8,1)
		_Frozen ("Frozen", Range(0, 1)) = 0
		_NoiseTex ("Noise", 2D) = "gray" {}
		_SpriteSize ("Sprite Size (pixels)", Vector) = (32,32,0,0)
	}
	SubShader {
		Tags { "Queue"="Background" "IgnoreProjector"="True" }
		LOD 100

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

			sampler2D _MainTex, _NoiseTex;
			fixed4 _FrozenCol;
			float _Frozen;
			float4 _SpriteSize;

			struct appdata {
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
				float2 uv1 : TEXCOORD1;   // position within the sprite, 0..1
			};

			struct v2f {
				float4 pos : SV_POSITION;
				float4 uv : TEXCOORD0;    // xy: _MainTex, zw: sprite-local
				float2 noiseUV : TEXCOORD1;
			};

			v2f vert (appdata v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv.xy = v.uv;
				o.uv.zw = v.uv1;
				o.noiseUV = v.uv1 * _SpriteSize.xy * 0.03125;
				return o;
			}

			fixed4 frag (v2f i) : SV_Target {
				fixed4 c = tex2D(_MainTex, i.uv.xy);
				clip(c.a - 0.2);

				float n = (tex2D(_NoiseTex, i.noiseUV).r - 0.5) * 0.1;
				float level = _Frozen * (2 / _SpriteSize.x + 1) + n;
				float fromBottom = 1 - i.uv.w;
				float frozen = saturate(floor(floor(level * _SpriteSize.x) / _SpriteSize.x + fromBottom));
				float below = saturate(floor(floor(level * _SpriteSize.x - 1) / _SpriteSize.x + fromBottom));
				float edge = max(frozen - below, 0);

				float lum = dot(c.rgb, float3(0.22, 0.707, 0.071));
				c.rgb = lerp(c.rgb, saturate(lum + _FrozenCol.rgb), frozen);
				c.rgb += edge * (1 - c.rgb);
				return c;
			}
			ENDCG
		}
	}
}
