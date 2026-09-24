// Rewrite of the game's "Custom/Fake3D No Lightmap" for GLES3.
// Same as Custom/Fake3D without the lightmap: vertex colour = lerp(_Shadow, _Color,
// N.lightDir); pixel = texture * colour * 2 + fresnel rim, scaled by saturate(1 + _CastCol).
Shader "Custom/Fake3D No Lightmap" {
	Properties {
		_MainTex ("Base (RGB)", 2D) = "white" {}
		_Color ("Color", Color) = (1,1,1,1)
		_Shadow ("Shadow", Color) = (0.5,0.5,0.5,1)
		_FresPow ("Fresnel Power", Range(0.1, 10)) = 2
		_FresCol ("Fresnel Color", Color) = (0,0,0,1)
		_CastCol ("Cast Shadow Color", Color) = (0,0,0,1)
	}
	SubShader {
		Tags { "Queue"="Geometry" "RenderType"="Opaque" }

		Pass {
			Tags { "LightMode"="ForwardBase" }
			ZTest LEqual
			ZWrite On
			Cull Back

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_fog
			#include "UnityCG.cginc"

			sampler2D _MainTex;
			float4 _MainTex_ST;
			fixed4 _Color, _Shadow, _FresCol, _CastCol;
			float _FresPow;
			float4 lightDir;

			struct appdata {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float2 uv : TEXCOORD0;
			};

			struct v2f {
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
				fixed4 color : COLOR;
				float3 normal : TEXCOORD1;
				float3 viewDir : TEXCOORD2;
				UNITY_FOG_COORDS(3)
			};

			v2f vert (appdata v) {
				v2f o;
				float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				o.normal = normalize(mul((float3x3)unity_ObjectToWorld, v.normal));
				o.color = lerp(_Shadow, _Color, saturate(dot(o.normal, lightDir.xyz)));
				o.viewDir = normalize(_WorldSpaceCameraPos - worldPos);
				UNITY_TRANSFER_FOG(o, o.pos);
				return o;
			}

			fixed4 frag (v2f i) : SV_Target {
				float rim = pow(1 - saturate(dot(i.normal, i.viewDir)), _FresPow);
				fixed3 tex = tex2D(_MainTex, i.uv).rgb;
				fixed3 c = saturate(rim * _FresCol.rgb * i.color.rgb + tex * i.color.rgb * 2);
				c *= saturate(_CastCol.rgb + 1);
				fixed4 col = fixed4(c, 1);
				UNITY_APPLY_FOG(i.fogCoord, col);
				return col;
			}
			ENDCG
		}
	}
}
