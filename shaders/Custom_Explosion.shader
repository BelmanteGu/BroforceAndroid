// Rewrite of the game's "Custom/Explosion" for GLES3 (3D fireball meshes).
// f = saturate(dot(worldNormal, (0,0,-1))) + _MainTex.a (scrolled by _ScrollSpeed) * _NoiseStr,
// saturated, raised to _RimPow, then used as the u coordinate into the _Lookup colour ramp.
// Opaque output. _Color and _Color2 are declared but unused by the original.
Shader "Custom/Explosion" {
	Properties {
		_Color ("Color", Color) = (1,1,1,1)
		_Color2 ("Color 2", Color) = (1,1,1,1)
		_MainTex ("Noise (A)", 2D) = "white" {}
		_Lookup ("Lookup", 2D) = "white" {}
		_ScrollSpeed ("Scroll Speed", Vector) = (0.1,0.1,0,0)
		_RimPow ("Rim Power", Float) = 1
		_NoiseStr ("Noise Strength", Float) = 0.5
	}
	SubShader {
		Tags { "Queue"="Transparent" }

		Pass {
			ZTest LEqual
			ZWrite On
			Cull Back

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"

			sampler2D _MainTex;
			sampler2D _Lookup;
			float4 _ScrollSpeed;
			float _RimPow;
			float _NoiseStr;

			struct appdata {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float2 uv : TEXCOORD0;
			};

			struct v2f {
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
				float3 normal : TEXCOORD1;
			};

			v2f vert (appdata v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				// Raw uv (no _MainTex_ST), scrolled over time.
				o.uv = v.uv + frac(_ScrollSpeed.xy * _Time.y);
				o.normal = mul((float3x3)unity_ObjectToWorld, v.normal);
				return o;
			}

			fixed4 frag (v2f i) : SV_Target {
				float facing = saturate(dot(normalize(i.normal), float3(0, 0, -1)));
				float n = tex2D(_MainTex, i.uv).a;
				float f = saturate(n * _NoiseStr + facing);
				f = min(pow(f, _RimPow), 1);
				return tex2D(_Lookup, float2(f, 0.5));
			}
			ENDCG
		}
	}
}
