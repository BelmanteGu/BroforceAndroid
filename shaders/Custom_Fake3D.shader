// Rewrite of the game's "Custom/Fake3D" for GLES3 (3D props in 2D levels).
// Vertex: colour = lerp(_Shadow, _Color, N.lightDir). Pixel: texture * colour * 2 plus a
// fresnel rim (_FresCol, _FresPow), optional lightmap, scaled by saturate(1 + _CastCol).
// The original also multiplies by the real-time shadow map; there are no real-time
// shadows in the Android port, which the original treats as fully lit.
Shader "Custom/Fake3D" {
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
			#pragma multi_compile __ LIGHTMAP_ON
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
				float2 uv1 : TEXCOORD1;
			};

			struct v2f {
				float4 pos : SV_POSITION;
				float4 uv : TEXCOORD0;      // xy: _MainTex, zw: lightmap
				fixed4 color : COLOR;
				float3 normal : TEXCOORD1;
				float3 viewDir : TEXCOORD2;
				UNITY_FOG_COORDS(3)
			};

			v2f vert (appdata v) {
				v2f o;
				float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv.xy = TRANSFORM_TEX(v.uv, _MainTex);
				o.uv.zw = v.uv1 * unity_LightmapST.xy + unity_LightmapST.zw;
				o.normal = normalize(mul((float3x3)unity_ObjectToWorld, v.normal));
				o.color = lerp(_Shadow, _Color, saturate(dot(o.normal, lightDir.xyz)));
				o.viewDir = normalize(_WorldSpaceCameraPos - worldPos);
				UNITY_TRANSFER_FOG(o, o.pos);
				return o;
			}

			fixed4 frag (v2f i) : SV_Target {
				float rim = pow(1 - saturate(dot(i.normal, i.viewDir)), _FresPow);
				fixed3 tex = tex2D(_MainTex, i.uv.xy).rgb;
				fixed3 c = saturate(rim * _FresCol.rgb * i.color.rgb + tex * i.color.rgb * 2);
				#ifdef LIGHTMAP_ON
				c *= DecodeLightmap(UNITY_SAMPLE_TEX2D(unity_Lightmap, i.uv.zw));
				#endif
				c *= saturate(_CastCol.rgb + 1);
				fixed4 col = fixed4(c, 1);
				UNITY_APPLY_FOG(i.fogCoord, col);
				return col;
			}
			ENDCG
		}
	}
}
