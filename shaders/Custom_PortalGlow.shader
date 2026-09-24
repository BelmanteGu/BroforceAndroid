// Rewrite of the game's "Custom/PortalGlow" for GLES3.
// Rim term = pow(saturate(dot(objectNormal, objectViewDir)), _RimPower), used as the u coordinate
// into the _MainTex colour ramp (v = 0.5). Premultiplied-alpha blend (One OneMinusSrcAlpha),
// no depth write.
Shader "Custom/PortalGlow" {
	Properties {
		_MainTex ("Glow Ramp", 2D) = "white" {}
		_RimPower ("Rim Power", Float) = 1
	}
	SubShader {
		Tags { "Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent" }

		Pass {
			Blend One OneMinusSrcAlpha
			ZTest LEqual
			ZWrite Off
			Cull Back

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"

			sampler2D _MainTex;
			float _RimPower;

			struct appdata {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
			};

			struct v2f {
				float4 pos : SV_POSITION;
				float3 normal : TEXCOORD0;
				float3 viewDir : TEXCOORD1;
			};

			v2f vert (appdata v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.normal = normalize(v.normal);
				o.viewDir = normalize(ObjSpaceViewDir(float4(v.vertex.xyz, 1)));
				return o;
			}

			fixed4 frag (v2f i) : SV_Target {
				float rim = pow(saturate(dot(normalize(i.normal), normalize(i.viewDir))), _RimPower);
				return tex2D(_MainTex, float2(rim, 0.5));
			}
			ENDCG
		}
	}
}
