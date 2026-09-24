// Rewrite of the game's "Custom Shaders/Distortion" for GLES3 (dissolve / slice effect).
// Pixels are discarded where any rgb channel of _SliceGuide is below _SliceAmount; the rest
// show _MainTex (alpha blended, no depth write, no culling, RGB-only writes).
// The original is a lit surface shader (albedo also added as light); rendered unlit here.
Shader "Custom Shaders/Distortion" {
	Properties {
		_MainTex ("Texture", 2D) = "white" {}
		_SliceAmount ("Slice Amount", Range(0, 1)) = 0.5
	}
	SubShader {
		Tags { "Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent" }

		Pass {
			Blend SrcAlpha OneMinusSrcAlpha
			ZTest LEqual
			ZWrite Off
			Cull Off
			ColorMask RGB

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"

			sampler2D _MainTex;
			float4 _MainTex_ST;
			// NOTE: _SliceGuide is not in the original Properties block; it is used by the
			// original code and is expected to be set on the material (or by script).
			sampler2D _SliceGuide;
			float4 _SliceGuide_ST;
			float _SliceAmount;

			struct appdata {
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f {
				float4 pos : SV_POSITION;
				float4 uv : TEXCOORD0;      // xy: _MainTex, zw: _SliceGuide
			};

			v2f vert (appdata v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv.xy = TRANSFORM_TEX(v.uv, _MainTex);
				o.uv.zw = TRANSFORM_TEX(v.uv, _SliceGuide);
				return o;
			}

			fixed4 frag (v2f i) : SV_Target {
				float3 g = tex2D(_SliceGuide, i.uv.zw).rgb - _SliceAmount;
				if (any(g < 0)) discard;
				// NOTE: the original base pass outputs tex + tex.rgb * ambient SH; ambient
				// lighting is dropped here.
				return tex2D(_MainTex, i.uv.xy);
			}
			ENDCG
		}
	}
}
