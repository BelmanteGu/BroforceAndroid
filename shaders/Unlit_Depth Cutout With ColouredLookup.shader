// Rewrite of the game's "Unlit/Depth Cutout With ColouredLookup" for GLES3.
// m = _MainTex * _Color; discard where m.a < 0.3. m.g picks the palette column and m.b the row in
// _AnimatedTex, whose u is advanced by an even frame index ceil(time / _FrameRate / 2) * 2 / _Frames.
// Output rgb = lookup * m.a, alpha = m.a; alpha blended, depth write on, RGB-only writes.
Shader "Unlit/Depth Cutout With ColouredLookup" {
	Properties {
		_MainTex ("Lookup Coords (G = column, B = row), Alpha (A)", 2D) = "white" {}
		_AnimatedTex ("Animated Palette", 2D) = "white" {}
		_Color ("Color", Color) = (1,1,1,1)
		_Speed ("Speed (unused)", Float) = 1
		_Frames ("Frames", Float) = 4
		_FrameRate ("Frame Rate (seconds per frame)", Float) = 0.1
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

			sampler2D _MainTex;
			sampler2D _AnimatedTex;
			fixed4 _Color;
			float _Frames;
			float _FrameRate;

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
				// NOTE: the original also computes a world-space scroll from _Speed that the
				// pixel shader never reads; it is omitted. Raw uv (no _MainTex_ST).
				o.uv = v.uv;
				return o;
			}

			fixed4 frag (v2f i) : SV_Target {
				float4 m = tex2D(_MainTex, i.uv) * _Color;
				clip(m.a - 0.3);
				float frame = ceil(_Time.y / _FrameRate * 0.5) * 2;
				float2 lookupUV = float2(frame / _Frames + m.g / _Frames, m.b);
				fixed3 lookup = tex2D(_AnimatedTex, lookupUV).rgb;
				return fixed4(lookup * m.a, m.a);
			}
			ENDCG
		}
	}
}
