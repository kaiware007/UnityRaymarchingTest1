Shader "Custom/Raymarching Volumetric Clouds  Example"
{
	Properties
	{
		[Header(March)]
		_MarchIterations("Iterations", Range(0, 100)) = 50

		[Header(Clouds)]
		_Iterations("Iterations", Range(0, 500)) = 325
		_ViewDistance("View Distance", Range(0, 5)) = 3.36
		_CloudDensity("Cloud Density", Vector) = (0.18, 0.8,0,0)
		_Color("Color", Color) = (0.5529, 0.47568, 1, 1)
	}
		SubShader
	{
		Pass
	{
		Blend SrcAlpha Zero

		CGPROGRAM
#pragma vertex vert
#pragma fragment frag
#include "UnityCG.cginc"

		// Global properties
		sampler2D _NoiseOffsets;
	float3 _CamPos;
	float3 _CamRight;
	float3 _CamUp;
	float3 _CamForward;
	float _AspectRatio;
	float _FieldOfView;

	// Local properties
	float4 _Color;
	int _MarchIterations;
	int _Iterations;
	float _ViewDistance;
	float2 _CloudDensity;

	struct v2f
	{
		float2 uv : TEXCOORD0;
		float4 vertex : SV_POSITION;
	};

	v2f vert(appdata_base  v)
	{
		v2f o;
		o.vertex = mul(UNITY_MATRIX_MVP, v.vertex);
		o.uv = v.texcoord;
		return o;
	}

	// Shamelessly stolen from https://www.shadertoy.com/view/4sfGzS
	float noise(float3 x) { 
		x *= 4.0; 
		float3 p = floor(x); 
		float3 f = frac(x); 
		f = f*f*(3.0 - 2.0*f); 
		float2 uv = (p.xy + float2(37.0, 17.0)*p.z) + f.xy; 
		float2 rg = tex2D(_NoiseOffsets, (uv + 0.5) / 256.0).yx; 
		return lerp(rg.x, rg.y, f.z); 
	}

	float fbm(float3 pos, int octaves) { 
		float f = 0.; 
		for (int i = 0; i < octaves; i++) { 
			f += noise(pos) / pow(2, i + 1); 
			pos *= 2.01; 
		} 
		f /= 1 - 1 / pow(2, octaves + 1); return f; 
	}

	float distFunc(float3 pos)
	{
		return length(pos) - 2;
	}

	float march(in float3 ray, inout float3 pos)
	{
		float hit = 0;
		for (int i = 0; i < _MarchIterations; i++)
		{
			float d = distFunc(pos);
			if (d < 0.01)
			{
				hit = 1;
				break;
			}
			pos.xyz += ray * d;
		}
		return hit;
	}

	fixed4 frag(v2f i) : SV_Target
	{
		float2 uv = (i.uv - 0.5) * _FieldOfView;
		uv.x *= _AspectRatio;

		float3 ray = _CamUp * uv.y + _CamRight * uv.x + _CamForward;
		//float3 ray = GetRayDirection(i.screenPos);
		float3 pos = _CamPos;
		float3 p = pos;

		float cloudDensity = 0;
		float maxDensity = 0;
		float hit = march(ray, pos);

		for (float i = 0; i < _Iterations; i++)
		{
			float sphere = smoothstep(0, -1, distFunc(p));
			float f = i / _Iterations;
			float alpha = smoothstep(0, 20, i) * (1 - f) * (1 - f);
			float clouds = smoothstep(_CloudDensity.x, _CloudDensity.y, fbm(p, 5)) * sphere;
			maxDensity = max(maxDensity, clouds + 0.1);
			cloudDensity += clouds * alpha * smoothstep(0.7, 0.4, maxDensity);
			p = pos + ray * f * _ViewDistance;
		}

		float cloudFactor = 1 - (cloudDensity / _Iterations) * 20 * _Color.a;
		float3 color = lerp(_Color.xyz, float3(1, 1, 1), smoothstep(0.2, 1, cloudFactor));
		return fixed4(color * cloudFactor, 1);
	}
		ENDCG
	}
	}
}