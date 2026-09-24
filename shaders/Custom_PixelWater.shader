// Rewrite of the game's "Custom/PixelWater" for GLES3.
// Two scrolling normal maps (offset = speed) bend the world normal; the reflection vector samples
// _Cube, which is fresnel-weighted by _FresCol and thresholded (_Cutoff) into _HighlightCol sparkles.
// Base = _MainTex * lerp(_ShadowCol, _LightCol, N.lightDir) * 2, optional lightmap, fog, * (1 + _CastCol).
// Real-time shadow map variants of the original are dropped (treated as fully lit, like Fake3D).
Shader "Custom/PixelWater" {
	Properties {
		_MainTex ("Base (RGB)", 2D) = "white" {}
		_Cube ("Reflection Cubemap", Cube) = "_Skybox" {}
		_Bump1 ("Normal Map 1, offset = scroll speed", 2D) = "bump" {}
		_Bump2 ("Normal Map 2, offset = scroll speed", 2D) = "bump" {}
		_BumpStr ("Bump Strength", Float) = 1
		_FresPow ("Fresnel Power", Range(0.1, 10)) = 2
		_FresCol ("Fresnel Color", Color) = (1,1,1,1)
		_ShadowCol ("Shadow Color", Color) = (0.5,0.5,0.5,1)
		_LightCol ("Light Color", Color) = (0.5,0.5,0.5,1)
		_Cutoff ("Highlight Cutoff", Float) = 2.5
		_HighlightCol ("Highlight Color", Color) = (1,1,1,1)
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
			samplerCUBE _Cube;
			sampler2D _Bump1;
			sampler2D _Bump2;
			float4 _Bump1_ST;
			float4 _Bump2_ST;
			float _BumpStr;
			float _FresPow;
			float _Cutoff;
			fixed4 _FresCol, _ShadowCol, _LightCol, _HighlightCol, _CastCol;
			float4 lightDir;

			struct appdata {
				float4 vertex : POSITION;
				float4 tangent : TANGENT;
				float3 normal : NORMAL;
				float2 uv : TEXCOORD0;
				float2 uv1 : TEXCOORD1;
			};

			struct v2f {
				float4 pos : SV_POSITION;
				float4 uv : TEXCOORD0;      // xy: _MainTex (raw uv), zw: lightmap
				float4 uvBump : TEXCOORD1;  // xy: _Bump1, zw: _Bump2
				float3 normal : TEXCOORD2;
				float3 tangent : TEXCOORD3;
				float3 binormal : TEXCOORD4;
				float3 viewDir : TEXCOORD5;
				UNITY_FOG_COORDS(6)
			};

			v2f vert (appdata v) {
				v2f o;
				float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv.xy = v.uv;
				o.uv.zw = v.uv1 * unity_LightmapST.xy + unity_LightmapST.zw;
				o.uvBump.xy = v.uv * _Bump1_ST.xy + frac(_Bump1_ST.zw * _Time.y);
				o.uvBump.zw = v.uv * _Bump2_ST.xy + frac(_Bump2_ST.zw * _Time.y);
				o.normal = mul((float3x3)unity_ObjectToWorld, v.normal);
				// NOTE: the original transforms the tangent as a float4 (w included), kept as is.
				o.tangent = mul(unity_ObjectToWorld, v.tangent).xyz;
				o.binormal = cross(o.normal, o.tangent) * v.tangent.w;
				o.viewDir = normalize(_WorldSpaceCameraPos - worldPos);
				UNITY_TRANSFER_FOG(o, o.pos);
				return o;
			}

			fixed4 frag (v2f i) : SV_Target {
				float4 b1 = tex2D(_Bump1, i.uvBump.xy);
				float4 b2 = tex2D(_Bump2, i.uvBump.zw);
				float2 n1 = float2(b1.x * b1.w, b1.y) * 2 - 1;
				float2 n2 = float2(b2.x * b2.w, b2.y) * 2 - 1;
				float3 tn = normalize(float3(n1 + n2, sqrt(1 - min(dot(n1, n1), 1))));
				tn = lerp(float3(0.5, 0.5, 1), tn, _BumpStr);
				float3 wn = normalize(i.tangent) * tn.x + normalize(i.binormal) * tn.y + normalize(i.normal) * tn.z;
				float3 refl = reflect(-i.viewDir, wn);
				float3 cube = texCUBE(_Cube, refl).rgb;
				float highlight = (cube.r + cube.g + cube.b - _Cutoff >= 0) ? 1.0 : 0.0;

				float fres = pow(1 - saturate(dot(i.normal, i.viewDir)), _FresPow);
				float3 reflCol = cube * fres * _FresCol.rgb;
				float3 light = lerp(_ShadowCol.rgb, _LightCol.rgb, saturate(dot(i.normal, lightDir.xyz))) * 2;
				float3 c = tex2D(_MainTex, i.uv.xy).rgb * light + reflCol;
				#ifdef LIGHTMAP_ON
				c = c * DecodeLightmap(UNITY_SAMPLE_TEX2D(unity_Lightmap, i.uv.zw)) + fres * _FresCol.rgb;
				#else
				c += fres * _FresCol.rgb;
				#endif
				c = saturate(highlight * _HighlightCol.rgb + c);
				c *= saturate(_CastCol.rgb + 1);
				fixed4 col = fixed4(c, 1);
				UNITY_APPLY_FOG(i.fogCoord, col);
				return col;
			}
			ENDCG
		}
	}
}
