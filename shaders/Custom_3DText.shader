// Rewrite of the game's "Custom/3DText" for GLES3.
// Pass 1: outline, the mesh pushed out along its normals by _Thickness, back faces only.
// Pass 2: the text itself, shaded between _ShadowCol and _Color by the angle between
// the world normal and _LightDir.
Shader "Custom/3DText" {
	Properties {
		_Color ("Color", Color) = (1,1,1,1)
		_ShadowCol ("Shadow Color", Color) = (0,0,0,1)
		_Thickness ("Outline Thickness", Float) = 0.1
		_OutlineCol ("Outline Color", Color) = (0,0,0,1)
		_LightDir ("Light Direction", Vector) = (0,0,-1,0)
	}
	SubShader {
		Tags { "Queue"="Transparent" }

		Pass {
			Blend SrcAlpha OneMinusSrcAlpha
			ZTest LEqual
			ZWrite Off
			Cull Front

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"

			float _Thickness;
			fixed4 _OutlineCol;

			float4 vert (float4 vertex : POSITION, float3 normal : NORMAL) : SV_POSITION {
				return UnityObjectToClipPos(float4(vertex.xyz + normalize(normal) * _Thickness, 1));
			}

			fixed4 frag () : SV_Target {
				return _OutlineCol;
			}
			ENDCG
		}

		Pass {
			ZTest LEqual
			ZWrite On
			Cull Back

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"

			fixed4 _Color, _ShadowCol;
			float4 _LightDir;

			struct v2f {
				float4 pos : SV_POSITION;
				fixed4 color : COLOR;
			};

			v2f vert (float4 vertex : POSITION, float3 normal : NORMAL) {
				v2f o;
				o.pos = UnityObjectToClipPos(vertex);
				float3 n = normalize(mul((float3x3)unity_ObjectToWorld, normal));
				float lit = saturate(dot(n, normalize(_LightDir.xyz)));
				o.color = lerp(_ShadowCol, _Color, lit);
				return o;
			}

			fixed4 frag (v2f i) : SV_Target {
				return i.color;
			}
			ENDCG
		}
	}
}
