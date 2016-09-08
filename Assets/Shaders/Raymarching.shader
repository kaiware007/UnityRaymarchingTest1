Shader "Raymarching/Test"
{

Properties
{
    _MainTex ("Main Texture", 2D) = "" {}
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

    #define PI 3.14159265358979

	// 距離関数
    float DistanceFunc(float3 pos)
    {
		float r = sin(0.25 * PI * _Time.y) * 1.5;
		//return sphere(repeat(pos, float3(4,3,5)), r + 0.5);
		float3 offset;
		offset.x = cos(0.213 * PI * _Time.y) * 2;
		offset.y = sin(0.387 * PI * _Time.y) * 2;
		offset.z = sin(0.723 * PI * _Time.y) * 2;
		float s1 = sphere(pos + offset, r + 3);
		float s1b = sphere(pos + offset, r + 2.9);
		float s2 = sphere(repeat(pos + float3(_Time.y, 0, 0), float3(2,2,2)), r);
		float s3 = sphere(pos, 1);
		float t1 = roundBox(pos + float3(cos(1.0 * _Time.y * PI) * 2.0, sin(1.0 * _Time.y * PI) * 2.0, 0), float3(2,2,2), abs(sin(_Time.y * PI)) * 0.25);
		return smoothMin(smoothMin(max(max(s1, -s2), -s1b), s3, 1.5), t1, 1.5);
		//return max(s1, -s2);	// subtract
		//return max(s1, s2);	// and
		//return min(s1, s2);	// or

		//float r = abs(sin(2 * PI * _Time.y / 2.0));
        //float d1 = roundBox(repeat(pos, float3(6, 6, 6)), 1, r);
        //float d2 = sphere(pos, 3.0);
        //float d3 = floor(pos - float3(0, -3, 0));
        //return smoothMin(smoothMin(d1, d2, 1.0), d3, 1.0);
    }

    #include "Libs/Raymarching.cginc"

    sampler2D _MainTex;

    GBufferOut frag(VertOutput i)
    {
        float3 rayDir = GetRayDirection(i.screenPos);	// レイの方向

        float3 camPos = GetCameraPosition();	// カメラの位置
        float maxDist = GetCameraMaxDistance();	// 最大移動距離

        float distance = 0.0;
        float len = 0.0;
        float3 pos = camPos + _ProjectionParams.y * rayDir;	// Near Planeから計算開始

		// Raymarching
        for (int i = 0; i < 128; ++i) {
            distance = DistanceFunc(pos);
            len += distance;
            pos += rayDir * distance;	//レイを進ませる
            if (distance < 0.001 || len > maxDist) break;	// 何かに衝突した or 最大移動距離に到達したら終了
        }

        if (distance > 0.001) discard;	// 近くに物体がない場合は終了

        float depth = GetDepth(pos);	// デプス取得
        float3 normal = GetNormal(pos);	// 法線取得

		// グリッド
		//float u = (1.0 - floor(fmod(pos.x, 2.0))) * 2;
		//float v = (1.0 - floor(fmod(pos.y, 2.0))) * 2;

		// 自前グリッド
		float span = 1;
		float width = 0.9;
		//float r = step(width, fmod(pos.x + 10000 + _Time.y, span));
		//float g = step(width, fmod(pos.y + 10000 + _Time.y, span));
		//float b = step(width, fmod(pos.z + 10000 + _Time.y, span));
		float r = step(width, fmod(pos.x + 10000, span));
		float g = step(width, fmod(pos.y + 10000, span));
		float b = step(width, fmod(pos.z + 10000, span));
        GBufferOut o;
        o.diffuse  = float4(1.0, 1.0, 1.0, 1.0);
        o.specular = float4(0.5, 0.5, 0.5, 1.0);
        //o.emission = tex2D(_MainTex, float2(u, v)) * 2;
		//o.emission = float4(r, g, b, 1);
		o.emission = float4(0.25, 0.5, 1, 1) * max(max(r,g),b) * 2;
		//o.emission = float4(0, 0, 0, 0);
		o.depth    = depth;
        o.normal   = float4(normal, 1.0);

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