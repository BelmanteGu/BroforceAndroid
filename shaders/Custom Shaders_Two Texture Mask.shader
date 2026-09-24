// Rewrite of the game's "Custom Shaders/Two Texture Mask" for GLES3.
// Same name and properties as the original, so existing materials pick it up.
// Used for gibs/bodies that get bloodied: where _SliceGuide.r exceeds _SliceAmount and
// _MainTexOther has coverage, the colour becomes 90% (_MainTexOther * _BloodColor) +
// 10% base. Alpha tested against _Cutoff.
// The original is a Lambert surface shader; Broforce's scenes carry no dynamic lights
// on these objects, so this port renders the albedo unlit (the original's forward base
// pass also adds the albedo itself on top of lighting).
Shader "Custom Shaders/Two Texture Mask" {
	Properties {
		_BloodColor ("Blood Color", Color) = (1,1,1,1)
		_MainTex ("Base (RGB) Trans (A)", 2D) = "white" {}
		_MainTexOther ("Other (RGB) Trans (A)", 2D) = "white" {}
		_SliceGuide ("Slice Guide (RGB)", 2D) = "white" {}
		_SliceAmount ("Slice Amount", Range(0, 1)) = 0.5
		_Cutoff ("Alpha cutoff", Range(0, 1)) = 0.5
	}
	SubShader {
		Tags { "Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="TransparentCutout" }
		LOD 200

		Pass {
			Blend SrcAlpha OneMinusSrcAlpha
			ZTest Less
			ZWrite On
			Cull Back
			ColorMask RGB
			Lighting Off

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"

			sampler2D _MainTex;
			sampler2D _MainTexOther;
			sampler2D _SliceGuide;
			float4 _MainTex_ST;
			float4 _SliceGuide_ST;
			fixed4 _BloodColor;
			float _SliceAmount;
			float _Cutoff;

			struct appdata {
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f {
				float4 pos : SV_POSITION;
				float4 uv : TEXCOORD0;   // xy: _MainTex, zw: _SliceGuide
			};

			v2f vert (appdata v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv.xy = TRANSFORM_TEX(v.uv, _MainTex);
				o.uv.zw = TRANSFORM_TEX(v.uv, _SliceGuide);
				return o;
			}

			fixed4 frag (v2f i) : SV_Target {
				fixed4 c = tex2D(_MainTex, i.uv.xy);
				if (tex2D(_SliceGuide, i.uv.zw).r - _SliceAmount > 0) {
					fixed4 other = tex2D(_MainTexOther, i.uv.xy);
					if (other.a > 0)
						c.rgb = other.rgb * _BloodColor.rgb * 0.9 + c.rgb * 0.1;
				}
				clip(c.a - _Cutoff);
				return c;
			}
			ENDCG
		}
	}
	Fallback "Transparent/Cutout/VertexLit"
}
