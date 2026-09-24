// Rewrite of the game's "Custom/TransparentGrass" for GLES3 (alpha-tested Fake3D foliage).
// Vertex: colour = lerp(_Shadow, _Color, saturate(N.lightDir)). Pixel: discard where
// _MainTex.a < _AlphaTest; texture * colour * 2 plus fresnel rim (_FresCol, _FresPow), then
// * saturate(1 + _CastCol), with fog. Real-time shadow receiving is dropped (fully lit, like Fake3D).
Shader "Custom/TransparentGrass" {
	Properties {
		_MainTex ("Base (RGB), Alpha (A)", 2D) = "white" {}
		_Color ("Color", Color) = (1,1,1,1)
		_Shadow ("Shadow", Color) = (0.5,0.5,0.5,1)
		_FresPow ("Fresnel Power", Range(0.1, 10)) = 2
		_FresCol ("Fresnel Color", Color) = (0,0,0,1)
		_CastCol ("Cast Shadow Color", Color) = (0,0,0,1)
		_AlphaTest ("Alpha Test", Range(0, 1)) = 0.5
	}
	SubShader {
		Tags { "Queue"="AlphaTest" "RenderType"="TransparentCutout" }

		Pass {
			Tags { "LightMode"="ForwardBase" }
			ZTest LEqual
			ZWrite On
			Cull Off

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_fog
			#include "UnityCG.cginc"

			sampler2D _MainTex;
			fixed4 _Color, _Shadow, _FresCol, _CastCol;
			float _FresPow;
			float _AlphaTest;
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
				// Raw uv (the original ignores _MainTex_ST).
				o.uv = v.uv;
				o.normal = normalize(mul((float3x3)unity_ObjectToWorld, v.normal));
				o.color = lerp(_Shadow, _Color, saturate(dot(o.normal, lightDir.xyz)));
				o.viewDir = normalize(_WorldSpaceCameraPos - worldPos);
				UNITY_TRANSFER_FOG(o, o.pos);
				return o;
			}

			fixed4 frag (v2f i) : SV_Target {
				fixed4 tex = tex2D(_MainTex, i.uv);
				clip(tex.a - _AlphaTest);
				float rim = pow(1 - saturate(dot(i.normal, i.viewDir)), _FresPow);
				fixed3 c = saturate(rim * _FresCol.rgb * i.color.rgb + tex.rgb * i.color.rgb * 2);
				c *= saturate(_CastCol.rgb + 1);
				fixed4 col = fixed4(c, 1);
				UNITY_APPLY_FOG(i.fogCoord, col);
				return col;
			}
			ENDCG
		}

		Pass {
			Tags { "LightMode"="ShadowCaster" }
			ZTest Less
			ZWrite On
			Cull Off

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_shadowcaster
			#include "UnityCG.cginc"

			sampler2D _MainTex;
			float _AlphaTest;

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
				clip(tex2D(_MainTex, i.uv).a - _AlphaTest);
				return 0;
			}
			ENDCG
		}
	}
}
