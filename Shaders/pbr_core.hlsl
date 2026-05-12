#ifndef INCLUDED_PBR_CORE
#define INCLUDED_PBR_CORE


// Shader Layer
uint _HideShaderLayer;

bool IsShowLayer()
{
    return (1 << _ShaderLayer & _HideShaderLayer) == 0;
}


half4 Sample(Texture2D tex, SamplerState samp, float2 uv, float2 dx, float2 dy)
{
    #if defined(_PARALLAXMODE_PIXEL) || !defined(SHADER_STAGE_FRAGMENT)
    return tex.SampleGrad(samp, uv, dx, dy);
    #else
    return tex.Sample(samp, uv);
    #endif
}

half SmoothnessGSAA(ShadingParams p)
{
    half3 dx = abs(ddx(p.N));
    half3 dy = abs(ddy(p.N));
    half dxy = max(dot(dx,dx), dot(dy,dy));
    half roughnessGSAA = dxy / (dxy * 5 + 0.002) * _GSAAStrength;
    return saturate(1-roughnessGSAA);
}

half SampleHeight(float2 uv, float2 dx, float2 dy)
{
    #ifdef _TEXTUREMODE_SEPARATE
    return Sample(_ParallaxMap, sampler_ParallaxMap, uv, dx, dy).r;
    #else
    return Sample(_PBRMap, sampler_PBRMap, uv, dx, dy)[_HeightChannel];
    #endif
}

float SmoothWave(float a)
{
    float t = abs(frac(a) * 2 - 1);
    return t*t*(3-2*t);
}

void POM(inout ShadingParams p, inout float depth, bool isFront, inout float2 uv_MainTex, inout half3x3 matrixTBN, float4 posSV, float2 dx, float2 dy, float uvDensity, out float2 ray, out float offset)
{
    depth = posSV.z;
    ray = 0;
    offset = 0;
    #ifdef _PARALLAXMODE_PIXEL

    float3 parallaxViewDirection = mul(matrixTBN, p.V);
    ray = parallaxViewDirection.xy / parallaxViewDirection.z * _Parallax;

    #ifdef _WINDMODE_POM
    float waveFactor = dot(p.posWorld,normalize(_WindDirection.xyz));
    waveFactor = waveFactor + SmoothWave(dot(p.posWorld,normalize(_WindDirection.zyx * float3(1,1,-1))) * 0.01) * 10 + SmoothWave(dot(p.posWorld,normalize(_WindDirection.zyx * float3(1,1,-1))) * 0.01743) * 10;
    float sin3, cos3;
    sincos(waveFactor*0.25 + _Time.y * 2.4, sin3, cos3);
    float sin4, cos4;
    sincos(waveFactor*0.63 + _Time.y * 3.9, sin4, cos4);
    float strength = (sin3 + sin4 + 1) / (1+1+1);
    float3 parallaxViewDirectionWind = mul(matrixTBN, _WindDirection);
    ray += parallaxViewDirectionWind.xy * _Parallax * 0.5 * strength;
    uv_MainTex += parallaxViewDirectionWind.xy * _Parallax * 0.5 * strength;
    matrixTBN[2] = normalize(matrixTBN[2] - _WindDirection.xyz * strength);
    matrixTBN[0] = OrthoNormalize(matrixTBN[0], matrixTBN[2]);
    matrixTBN[1] = OrthoNormalize(matrixTBN[1], matrixTBN[2]);
    #endif

    ray *= _MainTex_ST.xy / _MainTex_ST.x;
    if(!isFront) ray = -ray;
    uv_MainTex -= ray;
    float stepSize = 1.0/_ParallaxQuality;
    offset = ibuki(posSV) * stepSize * _ParallaxRandomize;
    if(IsShadowCaster())
    {
        stepSize = saturate(stepSize * 4);
        offset = 0;
    }
    float nextCount = 1;

    float count;
    [loop]
    for(count = offset; count < nextCount; count+=stepSize)
    {
        if(count < SampleHeight(uv_MainTex+ray*count, dx, dy)) offset = count;
    }
    nextCount = offset + stepSize;
    stepSize *= stepSize*4;


    [loop]
    for(count = offset; count < nextCount; count+=stepSize)
    {
        if(count < SampleHeight(uv_MainTex+ray*count, dx, dy)) offset = count;
    }

    offset = 1-offset;

    float3 posWorld = p.posWorld - p.V * offset / parallaxViewDirection.z * _Parallax / uvDensity;
    p.posWorld = posWorld;
    if(IsShadowCaster()) posWorld -= p.V * 0.02;
    float4 posSV2 = W2P(posWorld);
    depth = posSV2.z / posSV2.w;
    uv_MainTex += ray;
    #endif
}

#ifdef _WETNESSMODE_RAIN
float2 lilComputeRainRipple(float2 rainpos, float2 fracpos, float fractime)
{
    const float puddleCount = 3;
    const float puddleScale = 24;
    float step = puddleCount / puddleScale;

    fractime = fractime * 0.25;
    rainpos = rainpos * 0.5 + 0.25;

    float2 normal = rainpos - fracpos;
    float dist = length(normal);
    float wave = dist - fractime;
    float rippleloop = frac(wave * puddleScale);
    normal = normal * puddleScale;
    normal *= 1.0 - 2.0 * rippleloop;

    float rippleStrength = saturate(1.0/3.0 - abs(rippleloop - 0.5)) * 3.0;
    float attenuation = saturate(wave + step) / step;
    float drop = wave < 0 ? rippleStrength * attenuation : 0;
    return normal * drop;
}

float2 lilComputeRain(float3 posWorld, float scale, float speed, uint loopnum)
{
    float time = _Time.y * speed;
    float2 drop = 0.0;
    float invloop = rcp(loopnum);
    float2 scaledpos = posWorld.xz * scale;
    for(uint i = 0; i < loopnum; i++)
    {
        float offset = i * invloop;
        float2 offsetpos = scaledpos + offset * float2(1.0,3.72);
        float2 floorpos = floor(offsetpos);
        float2 fracpos = offsetpos - floorpos;
        float randtime = time + offset + lilRandom(floorpos*0.001);
        float floortime = floor(randtime);
        float fractime = randtime - floortime;
        float invtime = saturate(1.0 - fractime);
        float2 rainpos = lilRandom((offset + floortime * 0.001) + floorpos * 0.0015);
        drop += lilComputeRainRipple(rainpos, fracpos, fractime) * invtime * invtime * invtime;
    }
    float2 dd = fwidth(scaledpos);
    float fade = saturate(1.0 - dot(dd,dd)*200.0);
    return drop * fade * fade;
}
#endif

void DoDetail(inout ShadingParams p, inout half3 tangentNormal, half3x3 matrixTBN, float offset, float uvDensity, float2 dx, float2 dy, half mask, uint detailUV, float4 st, Texture2D tex, uint albedoblend, Texture2D bump, uint bumpblend, half bumpscale, float4 projection, float projectionSharpness, float projectionThreshold)
{
    half3x3 detailTBN = matrixTBN;
    if(detailUV) detailTBN = GetTBN(p.uv[detailUV], matrixTBN[2], p.V, GetMatrixI_V());
    float2 uv_Detail = p.uv[detailUV];

    // コメントアウトを消せばDetailにPOMを適用できるが精度が甘い
    /*
    #ifdef _PARALLAXMODE_PIXEL
    if(detailUV)
    {
        float3 parallaxViewDirection = mul(detailTBN, p.V);
        float2 ray = parallaxViewDirection.xy / float2(parallaxViewDirection.z, parallaxViewDirection.z) * _Parallax;
        uv_Detail = uv_Detail - ray * offset * UVDensity(p.posWorldOrig, ddx(uv_Detail), ddy(uv_Detail)) / uvDensity;
    }
    #endif
    */

    uv_Detail = uv_Detail * st.xy + st.zw;
    if(detailUV)
    {
        dx = ddx(uv_Detail);
        dy = ddy(uv_Detail);
    }
    else
    {
        dx *= st.x / _MainTex_ST.x;
        dy *= st.y / _MainTex_ST.y;
    }

    if(dot(projection.xyz,projection.xyz) > 0) mask *= saturate(dot(p.N, projection.xyz) * projectionSharpness - projectionThreshold * projectionSharpness);
    half4 detail1tex = Sample(tex, sampler_MainTex, uv_Detail, dx, dy);
    p.albedo = lilBlendColor(p.albedo, detail1tex.rgb, detail1tex.a * mask, albedoblend);
    half4 detail1bumpmap = Sample(bump, sampler_MainTex, uv_Detail, dx, dy);
    half detail1bumpscale = bumpblend ? bumpscale : bumpscale * mask;
    half3 detail1tangentNormal = UnpackScaleNormal(detail1bumpmap, detail1bumpscale);
    detail1tangentNormal = mul(matrixTBN, mul(detail1tangentNormal, detailTBN));
    tangentNormal = bumpblend ? lerp(tangentNormal, detail1tangentNormal, mask) : BlendNormals(tangentNormal, detail1tangentNormal);
}

#ifdef _WINDMODE_TREE
void DoTreeWind(inout appdata i, inout float3 posWorld, inout float3 normalWorld, float3 winddir)
{
    float str = 0;
    float strLeaf = 0;
    float waveFactor = dot(posWorld,normalize(winddir));
    if(_WindTreeMode == 0)
    {
        // Tree It
        str = i.color.b;
        strLeaf = i.color.r;
        //waveFactor = i.color.g;
    }
    else
    {
        // Unity Tree
        str = i.uv1.y;
        strLeaf = i.color.y * i.uv0.y;
        //waveFactor = i.color.g;
    }
    float sin1, cos1;
    sincos(waveFactor*11.3 + _Time.y * 11.3 * 0.57, sin1, cos1);
    float sin2, cos2;
    sincos(waveFactor*23.1 + _Time.y * 23.1 * 0.59, sin2, cos2);

    waveFactor = dot(O2W(0),normalize(winddir));
    float sin3, cos3;
    sincos(waveFactor*0.25 + _Time.y * 2.4, sin3, cos3);
    float sin4, cos4;
    sincos(waveFactor*0.63 + _Time.y * 3.9, sin4, cos4);
    float strength = (sin3 + sin4 + 1) / (1+1+1) * str * _WindBranchSoftness;

    winddir += float3(sin3+sin4,0,cos3+cos4) * 0.2;
    posWorld += winddir * strength;

    float strengthLeaf = (sin1+sin2) * (strength * 0.5 + 0.25 * str + 0.05) * strLeaf * _WindLeafSoftness;
    posWorld += winddir * strengthLeaf;
}
#endif

#ifdef _WINDMODE_CLOTH
void DoClothWind(inout appdata i, inout float3 posWorld, inout float3 normalWorld, float3 winddir)
{
    float str = 0;
    switch(_WindClothMode)
    {
        case 0: str = i.vertex.r; break;
        case 1: str = i.vertex.g; break;
        case 2: str = i.vertex.b; break;
        case 3: str = i.vertex.a; break;
        case 4: str = i.uv1.x; break;
        case 5: str = i.uv1.y; break;
    }
    float waveFactor = dot(posWorld,normalize(winddir)) - str * 0.25;
    float sin0, cos0;
    sincos(waveFactor*2.7 + _Time.y * 2.7 * 0.72, sin0, cos0);
    float sin1, cos1;
    sincos(waveFactor*11.3 + _Time.y * 11.3 * 0.72, sin1, cos1);
    float sin2, cos2;
    sincos(waveFactor*23.1 + _Time.y * 23.1 * 0.5, sin2, cos2);

    float sin3, cos3;
    sincos(waveFactor*0.25 + _Time.y * 2.4, sin3, cos3);
    float sin4, cos4;
    sincos(waveFactor*0.63 + _Time.y * 3.9, sin4, cos4);
    float strength = (sin3 + sin4 + 2.2) / (1+1+2.2) * str;

    float sin = sin0 * 6 + sin1 + sin2;
    float cos = cos0 * 6 + cos1 + cos2;
    sin *= strength / (6+1+1);
    cos *= strength / (6+1+1);
    posWorld += normalWorld * sin * 0.5;
    posWorld -= winddir * strength * 0.2;

    i.normal = normalize(lerp(i.normal, normalize(W2OVector(winddir)), -cos));
    i.tangent.xyz = OrthoNormalize(i.tangent.xyz, i.normal);
}
#endif

#ifdef _UVMODE_PLANAR
void Planar(inout ShadingParams p, inout half3x3 matrixTBN, inout float2 uv, inout float2 dx, inout float2 dy, float4 posSV)
{
    uv = p.posWorld.xz * _MainTex_ST.xy + _MainTex_ST.zw;
    matrixTBN[0] = OrthoNormalize(half3(1,0,0), matrixTBN[2]);
    matrixTBN[1] = OrthoNormalize(half3(0,0,1), matrixTBN[2]);
    dx = ddx(uv);
    dy = ddy(uv);
}
#endif

void BiPlanar(inout ShadingParams p, inout half3x3 matrixTBN, inout float2 uv, inout float2 dx, inout float2 dy, float4 posSV)
{
    float hash = ibuki(posSV+1) * 0.1 - 0.05;
    #if defined(SHADOWS_DEPTH)
        if(!IsPerspective()) hash = 0;
    #endif
    float signX = sign(matrixTBN[2].x);
    float signZ = sign(matrixTBN[2].z);
    float2 uvX = p.posWorld.zy * float2(signX,1);
    float2 uvZ = p.posWorld.xy * float2(signZ,1);
    float blendX = abs(matrixTBN[2].x);
    float blendZ = abs(matrixTBN[2].z);
    uv = (blendX+hash) > blendZ ? uvX : uvZ;
    matrixTBN[0] = (blendX+hash) > blendZ ? half3(0,0,signX) : half3(signZ,0,0);
    matrixTBN[1] = (blendX+hash) > blendZ ? half3(0,1,0) : half3(0,1,0);
    matrixTBN[0] = OrthoNormalize(matrixTBN[0], matrixTBN[2]);
    matrixTBN[1] = OrthoNormalize(matrixTBN[1], matrixTBN[2]);
    dx = blendX > blendZ ? ddx(uvX) : ddx(uvZ);
    dy = blendX > blendZ ? ddy(uvX) : ddy(uvZ);
}

#ifdef _UVMODE_TRIPLANAR
void TriPlanar(inout ShadingParams p, inout half3x3 matrixTBN, inout float2 uv, inout float2 dx, inout float2 dy, float4 posSV)
{
    float hash = ibuki(posSV+1) * 0.1 - 0.05;
    #if defined(SHADOWS_DEPTH)
        if(!IsPerspective()) hash = 0;
    #endif
    float signX = sign(matrixTBN[2].x);
    float signY = sign(matrixTBN[2].y);
    float signZ = sign(matrixTBN[2].z);
    float2 uvX = p.posWorld.zy * float2(signX,1);
    float2 uvY = p.posWorld.xz * float2(signY,1);
    float2 uvZ = p.posWorld.yx * float2(signZ,1);
    float blendX = abs(matrixTBN[2].x);
    float blendY = abs(matrixTBN[2].y);
    float blendZ = abs(matrixTBN[2].z);
    uv = (blendX+hash) > blendZ ? uvX : uvZ;
    uv = (blendY+hash) > blendX && (blendY+hash) > blendZ ? uvY : uv;
    matrixTBN[0] = (blendX+hash) > blendZ ? half3(0,0,signX) : half3(0,signZ,0);
    matrixTBN[0] = (blendY+hash) > blendX && (blendY+hash) > blendZ ? half3(signY,0,0) : matrixTBN[0];
    matrixTBN[1] = (blendX+hash) > blendZ ? half3(0,1,0) : half3(1,0,0);
    matrixTBN[1] = (blendY+hash) > blendX && (blendY+hash) > blendZ ? half3(0,0,1) : matrixTBN[1];
    matrixTBN[0] = OrthoNormalize(matrixTBN[0], matrixTBN[2]);
    matrixTBN[1] = OrthoNormalize(matrixTBN[1], matrixTBN[2]);
    uv = uv * _MainTex_ST.xy + _MainTex_ST.zw;
    dx = (blendY > blendX && blendY > blendZ ? ddx(uvY) : (blendX > blendZ ? ddx(uvX) : ddx(uvZ))) * _MainTex_ST.xy;
    dy = (blendY > blendX && blendY > blendZ ? ddy(uvY) : (blendX > blendZ ? ddy(uvX) : ddy(uvZ))) * _MainTex_ST.xy;
}
#endif

#ifdef _RANDOMIZE_UV
void RandomizeUV(inout half3x3 matrixTBN, inout float2 uv, float4 posSV)
{
    float hash = ibuki(posSV+2) * 0.2 + 0.4;
    float2 blend = pow(frac(uv),10);
    #if defined(SHADOWS_DEPTH)
        if(!IsPerspective()) hash = 0.5;
    #endif
    float2 uvoffset = float2(blend.x > hash, blend.y > hash);
    float angle = ibuki(float4(abs(floor(uv) + uvoffset),0,0)) * 6.28;
    uv = RotateVector2(uv, angle);
    matrixTBN[0] = RotateVector3(matrixTBN[0], matrixTBN[2], -angle);
    matrixTBN[1] = RotateVector3(matrixTBN[1], matrixTBN[2], -angle);
}
#endif

#ifdef _ATRASMASK
void FixAtras(inout float2 uv, float2 uvorig)
{
    float4 atrasmask = _AtrasMask.Sample(sampler_point_clamp, uvorig);
    atrasmask = floor(atrasmask * 16.0 + 0.5) / 16.0;
    float2 atrasscale = (atrasmask.ga-atrasmask.rb);
    uv = frac(uv / atrasscale) * atrasscale + atrasmask.rb;
}
#endif

#ifdef _SCREENINGMODE_AM
float4 AMScreeningPattern(float2 uv, float dd)
{
    float4 uvCM, uvYK;
    uvCM.xy = RotateUV(uv, 15.0 / 180.0 * 3.14159265359);
    uvCM.zw = RotateUV(uv, 75.0 / 180.0 * 3.14159265359);
    uvYK.xy = RotateUV(uv,  0.0 / 180.0 * 3.14159265359);
    uvYK.zw = RotateUV(uv, 45.0 / 180.0 * 3.14159265359);
    float4 dotCM = frac(uvCM) - 0.5;
    float4 dotYK = frac(uvYK) - 0.5;
    dotCM *= dotCM;
    dotYK *= dotYK;
    float4 lengthCMYK = sqrt(float4(dotCM.x+dotCM.y, dotCM.z+dotCM.w, dotYK.x+dotYK.y, dotYK.z+dotYK.w) * 2.0);
    lengthCMYK = saturate(lengthCMYK - lengthCMYK * dd + dd); //lerp(lengthCMYK, 1.0, dd);
    lengthCMYK = saturate(lengthCMYK * 0.95 + 0.025); // remove noise
    return lengthCMYK;
}

float3 RGB2CMYK(float3 col, float4 lengthCMYK, float dd, float ddOrig)
{
    float3 RGB = col;
    #if !UNITY_COLORSPACE_GAMMA
        RGB = pow(RGB + 0.001, 1.0/2.2);
    #endif
    float RGBMax = max(max(RGB.r, RGB.g), RGB.b);
    float4 CMYK = 1.001 - float4(RGB * rcp(RGBMax), RGBMax);

    CMYK = sqrt(CMYK);
    float4 printCMYK = saturate((lengthCMYK - CMYK) / dd);
    float blending = saturate(ddOrig * 3.0 - 2.0 + abs(dot(col,0.333333) - 0.5) * 2);
    return printCMYK.xyz * (printCMYK.w - printCMYK.w * blending) + col * blending; //lerp(printCMYK.xyz * printCMYK.w, col, blending);
}

float3 AMScreening(float3 col, float2 uv, float2 scale, float blur, float noiseStrength)
{
    float2 uvScaled = uv * scale;
    float ddOrig = fwidth(abs(uvScaled.x) + abs(uvScaled.y));
    float dd = saturate(ddOrig * blur);
    float4 lengthCMYK = AMScreeningPattern(uvScaled, dd);

    float ddNoise = saturate(ddOrig*2);
    noiseStrength = noiseStrength - noiseStrength * ddNoise;
    float noise = abs(frac(uvScaled.x * 3.0158516) - 0.5) + abs(frac(uvScaled.x * 2.7159816) - 0.5);
    noise +=      abs(frac(uvScaled.y * 3.6274217) - 0.5) + abs(frac(uvScaled.y * 2.2731362) - 0.5);
    noise +=      abs(frac((uvScaled.x+uvScaled.y) * 3.6274217) - 0.5) + abs(frac((uvScaled.x+uvScaled.y) * 2.2731362) - 0.5);
    noise +=      abs(frac((uvScaled.x-uvScaled.y) * 3.1636172) - 0.5) + abs(frac((uvScaled.x-uvScaled.y) * 2.4631762) - 0.5);
    lengthCMYK = saturate(lengthCMYK * (1 - noiseStrength * 2) + noiseStrength);
    lengthCMYK += noise * noiseStrength - noiseStrength * 2;

    return RGB2CMYK(col, lengthCMYK, dd, ddOrig);
}
#endif

#ifdef _WETNESSMODE_RAIN
float Minidrop(float2 celluv, float2 uv, float time, float scalex, float offset, float offsettime)
{
    time = frac(time+offsettime);
    float powtime = pow(1-time,15);
    float2 pos = float2(0.5+sin(uv.y*20)*0.2,offset);
    pos.y += powtime*0.1;
    if(celluv.y>pos.y) celluv.y = lerp(celluv.y, pos.y, powtime * 0.5);
    return saturate(smoothstep(0,1,saturate((1-length((celluv-pos)*float2(scalex,1).yx/(1-time*0.5))*4))) * (1-time*1.5));
}

float Minidrop2(float2 celluv, float2 pos, float time, float scalex)
{
    float drop = smoothstep(0,1,saturate(1-length((celluv-pos)*float2(scalex,1).yx)*6));
    float timeoffset = pos.y / 0.8 - 0.1;
    float droptime = frac(time+timeoffset);
    drop *= saturate(1-droptime*1.5);
    return drop;
}

void RainDrop(v2f i, inout ShadingParams p, half3 T, half3 B, half3 N, float4 posSV, inout half3 diff, inout half3 spec)
{
    half3x3 matrixTBN = float3x3(T,B,N);
    float2 uv, dx, dy = 0;
    BiPlanar(p, matrixTBN, uv, dx, dy, posSV);
    uv *= 20;
    float scalex = 10;
    uv.x *= scalex;
    uv = uv;
    uv.x += sin(uv.x) * 0.5;

    // 左右に曲げる
    uv.x += sin(uv.y * 4.33) * 0.3 + sin(uv.y * 35.92) * 0.02 + sin(uv.y * 59.3) * 0.02;
    uv.y += sin(uv.x * 4.33) * 0.005 + sin(uv.x * 7.33) * 0.005;
    uv.y += ibuki(float4(floor(abs(uv.x))+1,1,1,1)) + _Time.x * 0.3;

    float2 cell = floor(uv);
    float2 celluv = frac(uv);
    float rand = ibuki(float4(abs(cell),1,1));
    float time = frac(rand + _Time.x * 4);

    float droptime = time;
    float powtime = lerp(0,droptime,saturate(pow(smoothstep(0,1,droptime/0.75),30)));
    float2 pos;
    pos.x = 0.5;
    pos.y = 1-powtime;
    pos.y = pos.y * 0.8 + 0.1; // avoid clamp

    // 伸ばす
    float dropstretch = droptime * 0.4 + powtime * 0.6;
    float2 dropuv = celluv;
    if(dropuv.y>pos.y) dropuv.y = lerp(dropuv.y, pos.y, dropstretch*0.8);

    // 水滴
    float drop = smoothstep(0,1,saturate(1-length((dropuv-pos)*float2(scalex,1).yx)*2)) * (dropstretch * 2 + 2);
    drop = drop - drop * dropstretch;

    float2 wetnessuv = celluv;
    if(wetnessuv.y>pos.y) wetnessuv.y = lerp(wetnessuv.y, pos.y, pow(powtime, 0.1) * 0.98 * sqrt(rand));
    float wetness = sqrt(smoothstep(0,1,saturate(1-length((wetnessuv-pos)*float2(scalex,1).yx)*2)));
    wetness = wetness - wetness * dropstretch;

    // 残存
    drop += Minidrop2(celluv, float2(0.53,0.19+rand*0.3-0.15), powtime, scalex);
    drop += Minidrop2(celluv, float2(0.53,0.38+rand*0.3-0.15), powtime, scalex);
    drop += Minidrop2(celluv, float2(0.45,0.51+rand*0.3-0.15), powtime, scalex);
    drop += Minidrop2(celluv, float2(0.48,0.69+rand*0.3-0.15), powtime, scalex);
    drop += Minidrop2(celluv, float2(0.50,0.72+rand*0.3-0.15), powtime, scalex);
    wetness += Minidrop2(celluv, float2(0.53,0.19+rand*0.3-0.15), powtime, scalex);
    wetness += Minidrop2(celluv, float2(0.53,0.38+rand*0.3-0.15), powtime, scalex);
    wetness += Minidrop2(celluv, float2(0.45,0.51+rand*0.3-0.15), powtime, scalex);
    wetness += Minidrop2(celluv, float2(0.48,0.69+rand*0.3-0.15), powtime, scalex);
    wetness += Minidrop2(celluv, float2(0.50,0.72+rand*0.3-0.15), powtime, scalex);

    drop += Minidrop(celluv, uv, time, scalex, 0.15, 0.55);
    drop += Minidrop(celluv, uv, time, scalex, 0.35, 0.65);
    drop += Minidrop(celluv, uv, time, scalex, 0.55, 0.25);
    drop += Minidrop(celluv, uv, time, scalex, 0.65, 0.95);
    drop += Minidrop(celluv, uv, time, scalex, 0.85, 0.85);
    wetness += Minidrop(celluv, uv, time, scalex, 0.15, 0.55);
    wetness += Minidrop(celluv, uv, time, scalex, 0.35, 0.65);
    wetness += Minidrop(celluv, uv, time, scalex, 0.55, 0.25);
    wetness += Minidrop(celluv, uv, time, scalex, 0.65, 0.95);
    wetness += Minidrop(celluv, uv, time, scalex, 0.85, 0.85);

    wetness = saturate(wetness*2);

    drop *= 1-abs(N.y);
    wetness *= 1-abs(N.y);

    half blend = saturate(sqrt(drop));
    half3 normal = 0;
    normal.x = ddx_fine(drop);
    normal.y = ddy_fine(drop);
    normal.xy /= max(fwidth(uv.x/scalex), fwidth(uv.y)) * 200;
    normal = V2WVector(-normal);
    normal = normalize(normal*2*blend + p.N);

    p.N = normal;
    p.smoothness = lerp(p.smoothness, 1, wetness);
    p.perceptualRoughness = 1.2 - p.smoothness * 1.2;
    p.roughness = p.perceptualRoughness * p.perceptualRoughness;

    ShadingParams wp = p;
    wp.albedo = 0;
    wp.N = normal;
    wp.refN = wp.N;
    wp.metallic = 0;
    wp.reflectance = 0.2;
    wp.specular = 0.2;
    wp.isAnisotropy = false;
    wp.anisotropy = 0;
    wp.smoothness = 0.95;
    wp.perceptualRoughness = 1.2 - wp.smoothness * 1.2;
    wp.roughness = wp.perceptualRoughness * wp.perceptualRoughness;

    half3 wdiff, wspec, wreflectionStrength = 0;
    ComputeLights(wdiff, wspec, wreflectionStrength, wp, i);
    half3 wInvRef = saturate(1-wreflectionStrength * wetness);
    p.oneMinusReflectionStrength *= wInvRef;
    diff = diff * wInvRef;
    spec = spec * wInvRef + wspec * wetness;
    p.emission = p.emission * wInvRef;
}
#endif

void DoVertex(inout appdata i, out float4 pos, out float4 uv01, out float4 uv23, out float4 normal, out float4 tangent, out float4 binormal, out float4 color, out float3 V)
{
    float3 posWorld = O2W(i.vertex);
    float3 normalWorld = O2WNormal(i.normal.xyz);
    #ifdef _PARALLAXMODE_VERTEX
    posWorld += normalWorld.xyz * (SampleHeight(i.uv0 * _MainTex_ST.xy + _MainTex_ST.zw, 0, 0) * _Parallax - _Parallax) * 10 / _MainTex_ST.x;
    #endif
    #if defined(_WINDMODE_CLOTH)
    DoClothWind(i, posWorld, normalWorld, _WindDirection.xyz);
    #elif defined(_WINDMODE_TREE)
    DoTreeWind(i, posWorld, normalWorld, _WindDirection.xyz);
    #endif
    #if defined(_PARALLAXMODE_VERTEX) || defined(_WINDMODE_CLOTH) || defined(_WINDMODE_TREE)
    i.vertex.xyz = W2O(posWorld);
    #endif

    if(!IsShowLayer()
    #ifdef LIL_VRCHAT
    || !IsShow(abs(UNITY_MATRIX_P._m02) > 0.000001)
    #endif
    )
    {
        i.vertex = 0.0/0.0;
        posWorld = 0.0/0.0;
    }

    pos = O2P(i.vertex);
    uv01 = float4(i.uv0, i.uv1);
    uv23 = float4(i.uv2, i.uv3);
    normal.xyz = O2WNormal(i.normal);
    tangent.xyz = O2WVector(i.tangent.xyz);
    binormal.xyz = ComputeBinormal(normal.xyz, tangent.xyz, i.tangent.w);
    normal.w = posWorld.x;
    tangent.w = posWorld.y;
    binormal.w = posWorld.z;
    color = i.color;
    V = O2VDir(i.vertex);
}

half4 Shading(v2f i, float4 posSV, float3 posWorld, half3 V, half3 tangent, half3 binormal, half3 normal, half4 color, float2 uv[4], bool isFront, inout float depth)
{
    half3x3 matrixTBN = float3x3(tangent,binormal,normal);
    half3x3 matrixTBN4POM = float3x3(tangent,binormal,normal);

    ShadingParams p = (ShadingParams)0;
    p.uv = uv;
    p.posWorld = posWorld;
    p.posWorldOrig = posWorld;
    p.V = V;
    p.N = normal;
    p.origN = normal;
    float2 uv_MainTex = p.uv[0] * _MainTex_ST.xy + _MainTex_ST.zw;
    float2 dx = ddx(uv_MainTex);
    float2 dy = ddy(uv_MainTex);
    #if defined(_UVMODE_PLANAR)
    Planar(p, matrixTBN, uv_MainTex, dx, dy, posSV);
    #elif defined(_UVMODE_TRIPLANAR)
    TriPlanar(p, matrixTBN, uv_MainTex, dx, dy, posSV);
    #endif
    float uvDensity = UVDensity(posWorld, dx, dy);

    #ifdef _RANDOMIZE_UV
    RandomizeUV(matrixTBN, uv_MainTex, posSV);
    #endif

    float2 ray = 0;
    float offset = 0;
    POM(p, depth, isFront, uv_MainTex, matrixTBN, posSV, dx, dy, uvDensity, ray, offset);
    uv_MainTex = uv_MainTex-ray*offset;
    //p.uv[0] = p.uv[0]-ray / _MainTex_ST.xy*offset;
    p.uv[0] = uv_MainTex / _MainTex_ST.xy;

    #ifdef _ATRASMASK
    FixAtras(uv_MainTex, uv[0]);
    #endif

    // Albedo
    half4 mainTex = Sample(_MainTex, sampler_MainTex, uv_MainTex, dx, dy) * _Color;
    p.albedo = mainTex.rgb;
    p.alpha = mainTex.a;

    #ifdef _BACKFACE_COLOR
    half4 backfaceTex = Sample(_BackfaceTex, sampler_MainTex, uv_MainTex, dx, dy) * _BackfaceColor;
    if(isFront)
    {
        p.albedo = mainTex.rgb;
        p.albedoback = backfaceTex.rgb;
    }
    else
    {
        p.albedo = backfaceTex.rgb;
        p.albedoback = mainTex.rgb;
    }
    #endif

    #ifdef _SCREENINGMODE_AM
    p.albedo = AMScreening(p.albedo, uv_MainTex, float2(_ScreeningScaleX, _ScreeningScaleY), 1, _ScreeningNoiseStrength);
    p.albedoback = AMScreening(p.albedoback, uv_MainTex, float2(_ScreeningScaleX, _ScreeningScaleY), 1, _ScreeningNoiseStrength);
    #endif

    // Normal Map
    #ifdef _NORMALMAP
    half4 bumpmap = Sample(_BumpMap, sampler_MainTex, uv_MainTex, dx, dy);
    half3 tangentNormal = UnpackScaleNormal(bumpmap, _BumpScale);
    #else
    half4 bumpmap = half4(0.5,0.5,1,0.5);
    half3 tangentNormal = half3(0,0,1);
    #endif

    p.N = mul(tangentNormal, matrixTBN);
    half4 detailMask = Sample(_DetailMask, sampler_MainTex, uv_MainTex, dx, dy);
    #ifdef _DETAIL1
    DoDetail(p, tangentNormal, matrixTBN, offset, uvDensity, dx, dy, detailMask[0], _DetailUVMode1, _DetailTex1_ST, _DetailTex1, _DetailAlbedoBlend1, _DetailBumpMap1, _DetailBumpMapBlend1, _DetailBumpScale1, _DetailProjection1, _DetailProjectionSharpness1, _DetailProjectionThreshold1);
    #endif
    #ifdef _DETAIL2
    DoDetail(p, tangentNormal, matrixTBN, offset, uvDensity, dx, dy, detailMask[1], _DetailUVMode2, _DetailTex2_ST, _DetailTex2, _DetailAlbedoBlend2, _DetailBumpMap2, _DetailBumpMapBlend2, _DetailBumpScale2, _DetailProjection2, _DetailProjectionSharpness2, _DetailProjectionThreshold2);
    #endif
    #ifdef _DETAIL3
    DoDetail(p, tangentNormal, matrixTBN, offset, uvDensity, dx, dy, detailMask[2], _DetailUVMode3, _DetailTex3_ST, _DetailTex3, _DetailAlbedoBlend3, _DetailBumpMap3, _DetailBumpMapBlend3, _DetailBumpScale3, _DetailProjection3, _DetailProjectionSharpness3, _DetailProjectionThreshold3);
    #endif
    #ifdef _DETAIL4
    DoDetail(p, tangentNormal, matrixTBN, offset, uvDensity, dx, dy, detailMask[3], _DetailUVMode4, _DetailTex4_ST, _DetailTex4, _DetailAlbedoBlend4, _DetailBumpMap4, _DetailBumpMapBlend4, _DetailBumpScale4, _DetailProjection4, _DetailProjectionSharpness4, _DetailProjectionThreshold4);
    #endif

    p.N = normalize(mul(tangentNormal, matrixTBN));
    p.bentN = p.N;

    // PBR Map
    #ifdef _TEXTUREMODE_SEPARATE
    p.metallic = Sample(_MetallicGlossMap, sampler_MainTex, uv_MainTex, dx, dy).r;
    p.occlusion = Sample(_OcclusionMap, sampler_MainTex, uv_MainTex, dx, dy).r;
    p.smoothness = Sample(_SmoothnessMap, sampler_MainTex, uv_MainTex, dx, dy).r;
    #else
    half4 pbrmap = Sample(_PBRMap, sampler_MainTex, uv_MainTex, dx, dy);
    p.metallic = pbrmap[_MetallicChannel];
    p.occlusion = pbrmap[_OcclusionChannel];
    p.smoothness = pbrmap[_SmoothnessChannel];
    #endif
    p.metallic *= _Metallic;
    p.occlusion = lerp(1, p.occlusion, _OcclusionStrength);
    p.smoothness *= _Glossiness;

    //float2 uvScreen = ScreenUV(posSV);
    //float4 dir = mul(UNITY_MATRIX_VP, normal);
    //for(int offset = 1; offset < 33; offset++)
    //{
    //    float offx = offset/128.0*(ibuki(posSV+float4(offset*13,0,0,0))-0.5) * dir.w;
    //    float offy = offset/128.0*(ibuki(posSV+float4(offset*29,0,0,0))-0.5) * dir.w;
    //    float opaqueDepth = GetOpaqueDepth(uvScreen + float2(offx,offy));
    //    opaqueDepth -= dir.w * offset/128.0;
    //    if(posSV.w > opaqueDepth) p.occlusion *= saturate((posSV.w - opaqueDepth) / posSV.w) * 0.1 + 0.9;
    //    if(posSV.w > opaqueDepth) p.albedo *= saturate((posSV.w - opaqueDepth) / posSV.w) * 0.1 + 0.9;
    //}

    if(_VertexColorMode == 1)
    {
        p.albedo *= color.rgb;
        p.alpha *= color.a;
    }
    else if(_VertexColorMode == 2)
    {
        p.occlusion *= color.a;
    }

    // Metallic
    p.reflectance = _Reflectance;
    p.specular = lerp(p.reflectance, p.albedo, p.metallic);
    p.albedo = p.albedo - p.metallic * p.albedo;

    // GSAA
    half smoothnessGSAA = SmoothnessGSAA(p);
    p.smoothness = min(p.smoothness, smoothnessGSAA);

    // Anisotropy
    p.T = tangent;
    p.B = binormal;
    p.anisotropy = 0;
    p.refN = p.N;
    p.perceptualRoughness = 1.2;
    #ifdef _ANISOTROPY
        p.isAnisotropy = true;
        half4 anisoTangentMap = Sample(_AnisotropyDirection, sampler_MainTex, uv_MainTex, dx, dy);
        half3 anisoTangent = anisoTangentMap * 2 - 1;
        p.T = OrthoNormalize(normalize(mul(anisoTangent, matrixTBN)), p.N);
        p.B = cross(p.N, p.T);
        p.anisotropy = _Anisotropy * Sample(_AnisotropyMask, sampler_MainTex, uv_MainTex, dx, dy)[_AnisotropyChannel];
        half3 anisoDirectionWS = OrthoNormalize(p.V, p.anisotropy > 0.0 ? p.B : p.T);
        p.refN = normalize(lerp(p.N, anisoDirectionWS, abs(p.anisotropy)));
        p.perceptualRoughness = saturate(1.2 - abs(p.anisotropy));
    #endif

    p.perceptualRoughness = p.perceptualRoughness - p.smoothness * p.perceptualRoughness;
    p.roughness = p.perceptualRoughness * p.perceptualRoughness;

    // Emission
    #ifdef _EMISSION
    #ifdef _EMISSION_SUBPIXEL
    p.emission = _EmissionSubpixel.SampleGrad(sampler_trilinear_repeat, uv_MainTex * _EmissionSubpixel_ST.xy, dx * _EmissionSubpixel_ST.x * 2.5, dy * _EmissionSubpixel_ST.y * 2.5).rgb / _EmissionSubpixel.SampleGrad(sampler_point_clamp, float2(0.5,0.5), 2, 2).rgb;
    float2 dotuv = uv_MainTex * _EmissionSubpixel_ST.xy;
    dotuv = (floor(dotuv) + saturate(frac(dotuv) / saturate(fwidth(dotuv))) - 0.5) / _EmissionSubpixel_ST.xy;
    p.emission *= _EmissionMap.Sample(sampler_MainTex, dotuv).rgb * _EmissionColor.rgb;
    #else
    p.emission = Sample(_EmissionMap, sampler_MainTex, uv_MainTex, dx, dy).rgb * _EmissionColor.rgb;
    #endif
    #endif

    // Lighting
    OverrideByPlatform(p, i);
    p.oneMinusReflectionStrength = 1;
    half3 diff, spec, reflectionStrength;
    ComputeLights(diff, spec, reflectionStrength, p, i);
    p.oneMinusReflectionStrength *= saturate(1-reflectionStrength);

    #ifdef _CLEARCOAT
        ShadingParams cp = p;
        cp.albedo = 0;
        cp.T = tangent;
        cp.B = binormal;
        cp.metallic = 0;
        cp.reflectance = _ClearCoatReflectance;
        cp.specular = _ClearCoatReflectance;
        cp.isAnisotropy = false;
        cp.anisotropy = 0;

        half4 coatmap = Sample(_ClearCoatMask, sampler_MainTex, uv_MainTex, dx, dy);
        half coat = coatmap[_ClearCoatChannel] * _ClearCoat;
        cp.smoothness = min(coatmap[_ClearCoatSmoothnessChannel] * _ClearCoatSmoothness, smoothnessGSAA);
        cp.perceptualRoughness = 1.2 - cp.smoothness * 1.2;
        cp.roughness = cp.perceptualRoughness * cp.perceptualRoughness;

        #ifdef _CLEARCOAT_NORMALMAP
        half4 coatbumpmap = Sample(_ClearCoatBumpMap, sampler_MainTex, uv_MainTex, dx, dy);
        half3 coatTangentNormal = UnpackScaleNormal(coatbumpmap, _ClearCoatBumpScale);
        #else
        half4 coatbumpmap = half4(0.5,0.5,1,0.5);
        half3 coatTangentNormal = half3(0,0,1);
        #endif

        #ifdef _NORMALMAP
        half3 coatTangentNormalMain = tangentNormal;
        coatTangentNormalMain.xy *= _ClearCoatBaseBumpScale;
        coatTangentNormal = BlendNormals(coatTangentNormal, coatTangentNormalMain);
        #endif

        #if defined(_CLEARCOAT_NORMALMAP) || defined(_NORMALMAP)
        cp.N = mul(coatTangentNormal, matrixTBN);
        #else
        cp.N = normal;
        #endif
        cp.refN = cp.N;

        half3 cdiff, cspec, creflectionStrength = 0;
        ComputeLights(cdiff, cspec, creflectionStrength, cp, i);
        half3 cInvRef = saturate(1-creflectionStrength * coat);
        p.oneMinusReflectionStrength *= cInvRef;
        spec = spec * cInvRef + cspec * coat;
        p.emission = p.emission * cInvRef;
    #endif

    // Wetness
    #if defined(_WETNESSMODE_WETNESS) || defined(_WETNESSMODE_RAIN)
        #ifdef _WETNESSMODE_RAIN
        RainDrop(i, p, tangent, binormal, normal, posSV, diff, spec);
        #endif

        ShadingParams wp = p;
        wp.albedo = 0;
        wp.T = tangent;
        wp.B = binormal;
        wp.metallic = 0;
        wp.reflectance = 0.04;
        wp.specular = 0.04;
        wp.isAnisotropy = false;
        wp.anisotropy = 0;
        wp.smoothness = 1;
        wp.perceptualRoughness = 1.2 - wp.smoothness * 1.2;
        wp.roughness = wp.perceptualRoughness * wp.perceptualRoughness;
        half4 wbumpmap = 0;

        float wheight = SampleHeight(uv_MainTex, dx, dy);
        wheight = wheight + 1 - Sample(_WetnessMask, sampler_MainTex, uv_MainTex, dx, dy)[_WetnessChannel];
        float wblend = saturate(_WetnessDepth*normal.y - wheight);
        float wdepth = (1-wblend)*(1-wblend);
        float2 waveUV = (posWorld.xz - p.V.xz/p.V.y*(1-_WetnessDepth)/uvDensity*0.05) * _WetnessBumpMap_ST.xy;

        [unroll]
        for(int w = 0; w < 3; w++)
        {
            float2 scroll = float2(sin(w/3.0*6.28), cos(w/3.0*6.28));
            wbumpmap += _WetnessBumpMap.Sample(sampler_MainTex, waveUV + _Time.x * _WetnessBumpScroll * scroll) / 3.0;
        }
        half3 wtangentNormal = UnpackScaleNormal(wbumpmap, _WetnessBumpScale);
        wp.N = mul(wtangentNormal, matrixTBN);

        #ifdef _WETNESSMODE_RAIN
        float2 rainPuddle = lilComputeRain(posWorld, _RainScale, _RainSpeed, _RainLoop);
        wp.N = normalize(wp.N + float3(rainPuddle.x,0,rainPuddle.y));
        #endif
        wp.refN = wp.N;

        spec *= wdepth;
        diff *= lerp(_WetnessColor.rgb, 1, wdepth);
        half3 wdiff, wspec, wreflectionStrength = 0;
        ComputeLights(wdiff, wspec, wreflectionStrength, wp, i);
        half3 wInvRef = saturate(1-wreflectionStrength*wblend);
        p.oneMinusReflectionStrength *= wInvRef;
        spec = spec * wInvRef + wspec*wblend;
        p.emission = p.emission * wInvRef;

        p.smoothness = lerp(p.smoothness, 1, wblend);
        p.perceptualRoughness = 1.2 - p.smoothness * 1.2;
        p.roughness = p.perceptualRoughness * p.perceptualRoughness;
        p.N = normalize(p.N + wp.N * wblend * 4);
    #endif

    #ifdef _CLOTH
    half clothFactor = pow(1-abs(dot(p.N,p.V)), rcp(_ClothFuzz * 2));
    half3 clothColor = lerp(_ClothColor.rgb, _ClothColor.rgb * p.albedo, _ClothAlbedoBlend);
    p.albedo = lerp(p.albedo, clothColor, clothFactor*_Cloth);
    diff *= lerp(1, clothFactor, _Cloth*_ClothDark);
    #endif

    half4 col = 1;
    col.rgb = p.albedo * diff * p.oneMinusReflectionStrength;

    #ifdef _TRANSLUCENT
    half translucentRoughness = lerp(_TranslucentRoughness, _TranslucentRoughness * p.roughness, _TranslucentRoughnessBlend);
    half3 translucent = DoTranslucent(p, i, translucentRoughness) * lerp(_TranslucentColor.rgb, _TranslucentColor.rgb * p.albedo, _TranslucentAlbedoBlend);
    col.rgb = lerp(col.rgb, translucent, _Translucent);
    #endif

    #ifdef _SUBSURFACE
    half subsurfaceMask = Sample(_SubsurfaceMap, sampler_MainTex, uv_MainTex, dx, dy)[_SubsurfaceChannel];
    if(_SubsurfaceInvert != 0) subsurfaceMask = 1.0 - subsurfaceMask;
    half subsurface = pow(saturate(subsurfaceMask), _SubsurfacePower) * _SubsurfaceScattering;
    half subsurfaceRim = lerp(1, abs(dot(p.N, p.V)), _SubsurfaceRim);
    p.subsurfaceThickness = lerp(1, _SubsurfaceThickness * subsurfaceRim, subsurface);
    p.subsurfaceColor = lerp(_SubsurfaceColor.rgb, _SubsurfaceColor.rgb * min(p.albedo, p.albedoback), _SubsurfaceAlbedoBlend);
    half3 sdiff;
    ComputeSubsurface(sdiff, p, i);
    col.rgb = lerp(sdiff * p.subsurfaceColor, col.rgb, p.subsurfaceThickness);
    #endif

    #ifdef _CUTOUT
    col.a = saturate((p.alpha - _Cutoff) / fwidth(p.alpha));
    #endif
    #ifdef _DITHER
    if (_DitherRandomize) p.alpha = p.alpha + ibuki(i.pos) * 0.1 - 0.05;
    clip(p.alpha - (_DitherTex[uint2(posSV.xy)%4].r * 255 + 1) / (15+2));
    #endif
    #ifdef _TRANSPARENT
    col.a = lerp(1, p.alpha, p.oneMinusReflectionStrength);
    col.rgb *= p.alpha;
    #endif

    col.rgb += spec;

    float distFade = saturate((distance(posWorld, GetHeadPos()) - _DistanceFadeStart) / (_DistanceFadeEnd - _DistanceFadeStart)) * _DistanceFade;
    col.rgb = col.rgb - col.rgb * distFade;

    col.rgb += p.emission;

    // Fog
    #if defined(_TRANSPARENT)
    col.rgb = col.a == 0 ? col.rgb : col.rgb / col.a;
    DoFog(i, col, p);
    col.rgb *= col.a;
    #else
    DoFog(i, col, p);
    #endif

    #ifndef SHADER_API_MOBILE
    col.rgb = sqrt(col.rgb);
    col.rgb = col.rgb + ibuki(posSV) * 0.01;
    col.rgb = col.rgb * col.rgb;
    #endif

    return col;
}

void ShadingAlpha(v2f i, float4 posSV, float3 posWorld, half3 V, half3 tangent, half3 binormal, half3 normal, half4 color, float2 uv[4], bool isFront, inout float depth)
{
    half3x3 matrixTBN = float3x3(tangent,binormal,normal);

    ShadingParams p = (ShadingParams)0;
    p.uv = uv;
    p.posWorld = posWorld;
    p.posWorldOrig = posWorld;
    p.V = V;
    float2 uv_MainTex = p.uv[0] * _MainTex_ST.xy + _MainTex_ST.zw;
    float2 dx = ddx(uv_MainTex);
    float2 dy = ddy(uv_MainTex);
    #if defined(_UVMODE_PLANAR)
    Planar(p, matrixTBN, uv_MainTex, dx, dy, posSV);
    #elif defined(_UVMODE_TRIPLANAR)
    TriPlanar(p, matrixTBN, uv_MainTex, dx, dy, posSV);
    #endif
    float uvDensity = UVDensity(posWorld, dx, dy);

    #ifdef _RANDOMIZE_UV
    RandomizeUV(matrixTBN, uv_MainTex, posSV);
    #endif

    float2 ray = 0;
    float offset = 0;
    POM(p, depth, isFront, uv_MainTex, matrixTBN, posSV, dx, dy, uvDensity, ray, offset);
    uv_MainTex = uv_MainTex-ray*offset;
    p.uv[0] = p.uv[0]-ray / _MainTex_ST.xy*offset;

    #ifdef _ATRASMASK
    FixAtras(uv_MainTex, uv[0]);
    #endif

    half4 mainTex = _MainTex.Sample(sampler_MainTex, uv_MainTex) * _Color;
    half alpha = mainTex.a;

    #ifdef _TRANSLUCENT
    if(!IsPerspective())
    {
        half translucentBrightness = lerp(dot(_TranslucentColor.rgb,0.333333), dot(_TranslucentColor.rgb,0.333333) * dot(mainTex.rgb,0.333333), _TranslucentAlbedoBlend);
        alpha = lerp(alpha, alpha - alpha * translucentBrightness, _Translucent);
    }
    #endif
    #ifdef _CUTOUT
    clip(alpha - _Cutoff);
    #endif
    #if defined(_DITHER) || defined(_TRANSPARENT) || defined(_TRANSLUCENT)
        #if defined(SHADOWS_DEPTH)
            if(_DitherRandomize && IsPerspective()) alpha = alpha + ibuki(i.pos) * 0.1 - 0.05;
        #endif
    clip(alpha - (_DitherTex[uint2(posSV.xy)%4].r * 255 + 1) / (15+2));
    #endif
}

ShadingParams ShadingMeta(v2f i, float4 posSV, float2 uv[4])
{
    ShadingParams p = (ShadingParams)0;
    p.uv = uv;

    // Albedo
    float2 uv_MainTex = uv[0] * _MainTex_ST.xy + _MainTex_ST.zw;
    half4 mainTex = _MainTex.Sample(sampler_MainTex, uv_MainTex) * _Color;
    p.albedo = mainTex.rgb;
    p.alpha = mainTex.a;

    // PBR Map
    #ifdef _TEXTUREMODE_SEPARATE
    p.metallic = _MetallicGlossMap.Sample(sampler_MainTex, uv_MainTex).r;
    p.occlusion = _OcclusionMap.Sample(sampler_MainTex, uv_MainTex).r;
    p.smoothness = _SmoothnessMap.Sample(sampler_MainTex, uv_MainTex).r;
    #else
    half4 pbrmap = _PBRMap.Sample(sampler_MainTex, uv_MainTex);
    p.metallic = pbrmap[_MetallicChannel];
    p.occlusion = pbrmap[_OcclusionChannel];
    p.smoothness = pbrmap[_SmoothnessChannel];
    #endif
    p.metallic *= _Metallic;
    p.occlusion = lerp(1, p.occlusion, _OcclusionStrength);
    p.smoothness *= _Glossiness;

    // Metallic
    p.reflectance = _Reflectance;
    p.specular = lerp(p.reflectance, p.albedo, p.metallic);
    p.albedo = p.albedo - p.metallic * p.albedo;

    p.perceptualRoughness = p.perceptualRoughness - p.smoothness * p.perceptualRoughness;
    p.roughness = p.perceptualRoughness * p.perceptualRoughness;

    // Emission
    #ifdef _EMISSION
    p.emission = _EmissionMap.Sample(sampler_MainTex, uv_MainTex).rgb * _EmissionColor.rgb;
    #endif
    return p;
}

half4 UnpackAndShading(v2f i, float4 inormal, float4 itangent, float4 ibinormal, half4 color, float3 iV, float4 iuv01, float4 iuv23, bool isFront, inout float depth)
{
    float3 posWorld = float3(inormal.w, itangent.w, ibinormal.w);
    half3 V = GetVDir(posWorld, iV);
    half3 tangent = normalize(itangent.xyz);
    half3 binormal = normalize(ibinormal.xyz);
    half3 normal = inormal.xyz;
    if(!isFront)
    {
        tangent = -tangent;
        binormal = -binormal;
        normal = -normal;
    }
    if(dot(normal, V) < 0) normal = Ortho(normal, V);
    normal = normalize(normal);
    float2 uv[4];
    uv[0] = iuv01.xy;
    uv[1] = iuv01.zw;
    uv[2] = iuv23.xy;
    uv[3] = iuv23.zw;
    return Shading(i, i.pos, posWorld, V, tangent, binormal, normal, color, uv, isFront, depth);
}

void UnpackAndShadingAlpha(v2f i, float4 inormal, float4 itangent, float4 ibinormal, half4 color, float3 iV, float4 iuv01, float4 iuv23, bool isFront, inout float depth)
{
    float3 posWorld = float3(inormal.w, itangent.w, ibinormal.w);
    half3 V = GetVDir(posWorld, iV);
    half3 tangent = normalize(itangent.xyz);
    half3 binormal = normalize(ibinormal.xyz);
    half3 normal = inormal.xyz;
    if(!isFront)
    {
        tangent = -tangent;
        binormal = -binormal;
        normal = -normal;
    }
    if(dot(normal, V) < 0) normal = Ortho(normal, V);
    normal = normalize(normal);
    float2 uv[4];
    uv[0] = iuv01.xy;
    uv[1] = iuv01.zw;
    uv[2] = iuv23.xy;
    uv[3] = iuv23.zw;
    ShadingAlpha(i, i.pos, posWorld, V, tangent, binormal, normal, color, uv, isFront, depth);
}

#endif
