// Rewrite of the game's "Custom/Laserbeam" for GLES3.
// Vertex: the beam cross-section (object y/z) is scaled by _Width, pushed out along the
// normal by (cos + sin waves from _Params + _MinWidth) * _Params.y, and bent in z by a sine
// from _BendParams; both scaled by vertex alpha. Pixel: _MainTex distorted by scrolling
// _BumpTex, plus a fresnel rim (_RimPower) * _Color, saturated, times _Tint. Alpha blended.
Shader "Custom/Laserbeam" {
	Properties {
		_MainTex ("Base (RGB), Alpha (A)", 2D) = "white" {}
		_BumpTex ("Distortion (Normal)", 2D) = "bump" {}
		_DistortStr ("Distort Strength", Float) = 0.05
		_Params ("Wave (freq A, amplitude, speed, freq B)", Vector) = (1,0.1,1,1)
		_MinWidth ("Min Width", Float) = 1
		_RimPower ("Rim Power", Float) = 2
		_Color ("Rim Color", Color) = (1,1,1,1)
		_Width ("Width", Range(0,2)) = 1
		_Tint ("Tint", Color) = (1,1,1,1)
		_BendParams ("Bend (freq, amplitude, speed, -)", Vector) = (0,0,0,0)
	}
	SubShader {
		Tags { "Queue"="Transparent" }

		Pass {
			Blend SrcAlpha OneMinusSrcAlpha
			ZTest LEqual
			ZWrite Off
			Cull Back

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"

			sampler2D _MainTex;
			float4 _MainTex_ST;
			sampler2D _BumpTex;
			float4 _BumpTex_ST;
			float _DistortStr;
			float4 _Params;
			float _MinWidth;
			float _RimPower;
			fixed4 _Color;
			float _Width;
			fixed4 _Tint;
			float4 _BendParams;

			struct appdata {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float2 uv : TEXCOORD0;
				fixed4 color : COLOR;
			};

			struct v2f {
				float4 pos : SV_POSITION;
				float4 uv : TEXCOORD0;      // xy: _MainTex, zw: _BumpTex
				float3 normal : TEXCOORD1;
			};

			v2f vert (appdata v) {
				v2f o;
				float t = _Time.y;
				float wobble = cos(_Params.z * t * 1.1 - v.vertex.x * _Params.w)
					+ sin(_Params.z * t - v.vertex.x * _Params.x) + _MinWidth;
				float2 pushOut = wobble * normalize(v.normal.yz) * _Params.y;
				float bend = sin(v.vertex.x * _BendParams.x + _BendParams.z * t) * _BendParams.y;
				float2 yz = v.vertex.yz * _Width + float2(0, bend * v.color.a) + pushOut * v.color.a;
				o.pos = UnityObjectToClipPos(float4(v.vertex.x, yz, 1));
				o.uv.xy = v.uv * _MainTex_ST.xy + frac(_MainTex_ST.zw * t);
				o.uv.zw = v.uv * _BumpTex_ST.xy + frac(_BumpTex_ST.zw * t);
				o.normal = mul((float3x3)unity_ObjectToWorld, v.normal);
				return o;
			}

			fixed4 frag (v2f i) : SV_Target {
				// The original uses a fixed view direction of (0,0,-1) (orthographic side view).
				float rim = pow(1 - saturate(-normalize(i.normal).z), _RimPower);
				float2 offset = tex2D(_BumpTex, i.uv.zw).xy * 2 - 1;
				fixed4 tex = tex2D(_MainTex, i.uv.xy + offset * _DistortStr);
				return saturate(rim * _Color + tex) * _Tint;
			}
			ENDCG
		}
	}
}
