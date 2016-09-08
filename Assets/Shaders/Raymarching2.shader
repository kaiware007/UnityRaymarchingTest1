Shader "Raymarching/Test2"
{

Properties
{
    _MainTex ("Main Texture", 2D) = "" {}
	_SphereRadius ("Sphere Radius", float) = 1.0
	_SphereInterval ("Sphere Interval", float) = 10.0
	_PillarSize("Pillar Size", float) = 1.0
	_NoiseOffsets("Noise Tex", 2D) = "" {}
	_DistanceDencity("Distance Density", float) = 1.0
}

SubShader
{

Tags { "RenderType" = "Opaque" "DisableBatching" = "True" "Queue" = "Geometry+10" }
Cull Off

Pass
{
	Tags { "LightMode" = "Deferred" }

	// Deferred Rendering のベースとライティングのパスでは Stencil バッファはライティング用途に使われます。
	Stencil
	{
		Comp Always
		Pass Replace
		Ref 128
	}

	CGPROGRAM
	#pragma vertex vert
	#pragma fragment frag
	#pragma target 3.0
	#pragma multi_compile ___ UNITY_HDR_ON

	#include "UnityCG.cginc"
	#include "Libs/Utils.cginc"
	#include "Libs/Primitives.cginc"
	//#include "Libs/ClassicNoise3D.cginc"
	//#include "Libs/SimplexNoise3D.cginc"

	#define PI 3.14159265358979

	float _SphereRadius;
	float _SphereInterval;
	float _PillarSize;
	float _DistanceDencity;

	sampler2D _NoiseOffsets;

	// 距離関数
    float DistanceFunc(float3 pos)
    {
		// 節
		float s1 = sphere(repeat(pos, float3(_SphereInterval, _SphereInterval, _SphereInterval)), _SphereRadius);
		// 横棒
		float b1 = cylinder(
			rotate(
				repeat(pos, float3(_SphereInterval, _SphereInterval, _SphereInterval)), 
				90.0 * PI / 180.0, float3(0, 1, 0)),
			float2(_PillarSize, _SphereInterval)
			);
		// 縦棒
		float b2 = cylinder(
			rotate(
				repeat(pos, float3(_SphereInterval, _SphereInterval, _SphereInterval)),
				90.0 * PI / 180.0, float3(1, 0, 0)),
			float2(_PillarSize, _SphereInterval)
			);
		// 奥棒
		float b3 = cylinder(
			repeat(pos, float3(_SphereInterval, _SphereInterval, _SphereInterval)),
			float2(_PillarSize, _SphereInterval)
			);

		return min(min(min(s1, b1), b2), b3);
		//return smoothMin(smoothMin(smoothMin(s1, b1, 0.999), b2, 0.999), b3, 0.999);
		//return max(min(min(min(s1, b1), b2), b3), c);
    }

	// Shamelessly stolen from https://www.shadertoy.com/view/4sfGzS
	float noise(float3 x) {
		//x *= 4.0;
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
		f /= 1 - 1 / pow(2, octaves + 1); 
		return f;
	}

    #include "Libs/Raymarching.cginc"

    sampler2D _MainTex;

	const float3x3 m = float3x3(0.00, 0.80, 0.60,
		-0.80, 0.36, -0.48,
		-0.60, -0.48, 0.64);

	const float s = 0.00075;

    GBufferOut frag(VertOutput i)
    {
        float3 rayDir = GetRayDirection(i.screenPos);	// レイの方向

        float3 camPos = GetCameraPosition();	// カメラの位置
        float maxDist = GetCameraMaxDistance();	// 最大移動距離

        float distance = 0.0;
        float len = 0.0;
        float3 pos = camPos + _ProjectionParams.y * rayDir;	// Near Planeから計算開始

		float marchCount = 0.0;
		// Raymarching
        for (int i = 0; i < 512; ++i) {
            distance = DistanceFunc(pos);
            len += distance;
            pos += rayDir * distance;	//レイを進ませる
			marchCount += 1.0;
            if (distance < 0.001 || len > maxDist) break;	// 何かに衝突した or 最大移動距離に到達したら終了
        }

        if (distance > 0.001) discard;	// 近くに物体がない場合は終了

		float glow = 0.0;
        float depth = GetDepth(pos);	// デプス取得
        float3 normal1 = GetNormal(pos);	// 法線取得
		//float3 normal2 = GetNormal(pos + float3(s, 0, 0));
		//float3 normal3 = GetNormal(pos + float3(0, s, 0));

		//if (dot(normal1, normal2) > 0.9 || dot(normal1, normal3) > 0.9) {
		//	glow = 1.0;
		//}

		// グリッド
		//float u = (1.0 - floor(fmod(pos.x, 2.0))) * 2;
		//float v = (1.0 - floor(fmod(pos.y, 2.0))) * 2;

		// 自前グリッド
		//float span = 1;
		//float width = 0.9;
		//float r = step(width, fmod(pos.x + 10000 + _Time.y, span));
		//float g = step(width, fmod(pos.y + 10000 + _Time.y, span));
		//float b = step(width, fmod(pos.z + 10000 + _Time.y, span));
		//float r = step(width, fmod(pos.x + 10000, span));
		//float g = step(width, fmod(pos.y + 10000, span));
		//float b = step(width, fmod(pos.z + 10000, span));

		//float n = 0.5;
		////float s = 2.0;
		//float s = 0.002;
		//float w = 0.5;
		////float w = 0.25;
		////for (int i = 0; i < 1; i++)
		//{
		//	float3 coord = float3(pos * 0.5 * s + float3(_Time.y, 0, _Time.y) * 0.15);
		//	//float3 coord = float3(pos * 0.015 * s * _Time.y);
		//	//float3 coord = float3(pos * s);
		//	float3 period = float3(s, s, 1.0) * 2.0;
		//	
		//	// perlin noise
		//	n += pnoise(coord, period) * w;		
		//	// simplex noise
		//	//n += snoise(coord) * w;

		//	s *= 2.0;
		//	w * 0.5;
		//}
		//float4 emi = pnoise(pos * 0.2, float3(1, 1, 1) * 2);
		//
		//float c = smoothstep(0.5, 0.5016, n);
		//float c = n;
		//float c = 1;

		float3 q = pos * 0.005 + float3(_Time.y, _Time.y, _Time.y) * 0.015;
		float f = fbm(q, 5);
		//float3 q = pos * 0.005 + float3(_Time.y, _Time.y, _Time.y) * 0.015;
		//float f = 0.5 * noise(q); 
		//q = mul(m, q) * 2.01;
		//f += 0.25 * noise(q); 
		//q = mul(m, q) * 2.02;
		//f += 0.125 * noise(q); 
		//q = mul(q, m) * 2.03;
		//f += 0.0625 * noise(q); 
		//q = mul(q, m) * 2.01;
		float c = smoothstep(0.5, 0.5016, f);

        GBufferOut o;
        o.diffuse  = float4(1.0, 1.0, 1.0, 1.0);
		//o.diffuse = float4(1.0, 1.0, 1.0, 1.0) - fixed4(1,1,1,1) * marchCount * _DistanceDencity;
        o.specular = float4(0.0, 0.0, 0.0, 1.0);
        //o.emission = tex2D(_MainTex, float2(u, v)) * 2;
		//o.emission = float4(r, g, b, 1);
		//o.emission = float4(0.25, 0.5, 1, 1) * max(max(r,g),b) * 2;
		//o.emission = float4(0, 0, 0, 0);
		//o.emission = float4(c, c, c, 1.0);
		o.emission = float4(f, f, f, 1.0);
		//o.emission = float4(f, f, f, 1.0) - fixed4(1, 1, 1, 1) * marchCount * _DistanceDencity + glow * 0.5;
		//o.emission = float4(f, f, f, 1.0) + fixed4(1, 1, 1, 1) * marchCount * _DistanceDencity;

		o.depth    = depth;
        o.normal   = float4(normal1, 1.0);

#ifndef UNITY_HDR_ON
        o.emission = exp2(-o.emission);
#endif

        return o;
    }

    ENDCG
}

}

Fallback Off
}