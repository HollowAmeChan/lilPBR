#ifndef INCLUDED_LILPBR_CRYSTAL_RAYMARCH
#define INCLUDED_LILPBR_CRYSTAL_RAYMARCH

struct CrystalRaymarchInput
{
    float3 position;
    float3 viewDirection;
    float3 normal;
    float refraction;
    float refractionSurfaceNoise;
    float stepLength;
    float volumeNoiseScale;
    float volumeNoiseExp;
    float volumeNoiseMultiply;
    float secondaryExp;
    float secondaryMultiply;
    float linearMaskScale;
    float linearMaskNegate;
    float linearMaskOffset;
    float3 linearMaskVector;
    float3 linearMaskWorldOffset;
};

struct CrystalRaymarchOutput
{
    half mainMask;
    half secondaryMask;
};

float2 SampleCrystalVolumeTriplanar(float3 position, float scale)
{
    float2 sampleXY = SAMPLE_TEXTURE2D(_CrystalVolumeNoise, sampler_CrystalVolumeNoise, position.xy * scale).rg;
    float2 sampleZY = SAMPLE_TEXTURE2D(_CrystalVolumeNoise, sampler_CrystalVolumeNoise, position.zy * scale + float2(144.23, 5444.12)).rg;
    float2 sampleXZ = SAMPLE_TEXTURE2D(_CrystalVolumeNoise, sampler_CrystalVolumeNoise, position.xz * scale + float2(3127.11, 1522.12)).rg;
    return sampleXY * sampleZY * sampleXZ;
}

half CrystalLinearMask(float3 position, CrystalRaymarchInput input)
{
    float axisMask = (dot(position - input.linearMaskWorldOffset, input.linearMaskVector) + input.linearMaskOffset) * input.linearMaskScale;
    return saturate(saturate(axisMask) + input.linearMaskNegate);
}

CrystalRaymarchOutput CrystalRaymarch8(CrystalRaymarchInput input)
{
    float refraction = max(input.refraction, 0.001);
    float surfaceNoise = max(input.refractionSurfaceNoise, 0.001);
    float eta = saturate(1.0 - (surfaceNoise / refraction));
    float3 ray = refract(normalize(input.viewDirection), normalize(input.normal), eta);
    float stepLength = min(max(input.stepLength, 0.0), 4.0);
    float volumeNoiseScale = min(max(input.volumeNoiseScale, 0.001), 4.0);
    float volumeNoiseExp = min(max(input.volumeNoiseExp, 0.05), 4.0);
    float volumeNoiseMultiply = min(max(input.volumeNoiseMultiply, 0.0), 16.0);
    float secondaryExp = min(max(input.secondaryExp, 0.05), 4.0);
    float secondaryMultiply = min(max(input.secondaryMultiply, 0.0), 8.0);

    float stepDistance = 0.0;
    float mainMask = 0.0;
    float secondaryMask = 0.0;

    [unroll]
    for (int i = 0; i < 8; i++)
    {
        float3 samplePosition = input.position + ray * stepDistance;
        float2 volumeNoise = SampleCrystalVolumeTriplanar(samplePosition, volumeNoiseScale);
        half linearMask = CrystalLinearMask(samplePosition, input);

        mainMask += pow(saturate(pow(saturate(volumeNoise.r), volumeNoiseExp) * volumeNoiseMultiply * 1.45), 1.25) * saturate(1.0 - (i / 20.0)) * linearMask;
        secondaryMask += pow(saturate(volumeNoise.g), secondaryExp * 0.95) * secondaryMultiply * 2.0 * linearMask;

        stepDistance += stepLength * 0.125;
    }

    CrystalRaymarchOutput output;
    output.mainMask = saturate(mainMask);
    output.secondaryMask = saturate(secondaryMask);
    return output;
}

#endif
