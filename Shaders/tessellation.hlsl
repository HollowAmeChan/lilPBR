struct TessellationFactors {
    float edge[3] : SV_TessFactor;
    float inside : SV_InsideTessFactor;
};

appdata vertTess(appdata input)
{
    return input;
}

[domain("tri")]
[partitioning("fractional_odd")]
[outputtopology("triangle_cw")]
[patchconstantfunc("hullConst")]
[outputcontrolpoints(3)]
appdata hull(InputPatch<appdata, 3> input, uint id : SV_OutputControlPointID)
{
    return input[id];
}

float CalcEdgeTessFactor(float3 wpos0, float3 wpos1)
{
    float3 temp = 0.5 * (wpos0+wpos1) - _WorldSpaceCameraPos.xyz;
    return clamp(distance(wpos0, wpos1) * rsqrt(dot(temp, temp)) * _ScreenParams.y / _TessEdge, 1, _TessFactorMax);
}

TessellationFactors hullConst(InputPatch<appdata, 3> input)
{
    TessellationFactors output = (TessellationFactors)0;
    UNITY_SETUP_INSTANCE_ID(input[0]);

    float3 pw0 = O2W(input[0].vertex);
    float3 pw1 = O2W(input[1].vertex);
    float3 pw2 = O2W(input[2].vertex);

    float4 tessFactor;
    tessFactor.x = CalcEdgeTessFactor(pw1, pw2);
    tessFactor.y = CalcEdgeTessFactor(pw2, pw0);
    tessFactor.z = CalcEdgeTessFactor(pw0, pw1);
    tessFactor.w = dot(tessFactor.xyz, 1.0/3.0);

    output.edge[0] = tessFactor.x;
    output.edge[1] = tessFactor.y;
    output.edge[2] = tessFactor.z;
    output.inside  = tessFactor.w;
        
    return output;
}

#define TRI_INTERPOLATION(i,o,bary,type) o.type = bary[0] * i[0].type + bary[1] * i[1].type + bary[2] * i[2].type
[domain("tri")]
v2f domain(TessellationFactors hsConst, const OutputPatch<appdata, 3> input, float3 bary : SV_DomainLocation)
{
    appdata output = (appdata)0;
    UNITY_TRANSFER_INSTANCE_ID(input[0], output);

    TRI_INTERPOLATION(input,output,bary,vertex);
    TRI_INTERPOLATION(input,output,bary,uv0);
    TRI_INTERPOLATION(input,output,bary,uv1);
    TRI_INTERPOLATION(input,output,bary,uv2);
    TRI_INTERPOLATION(input,output,bary,uv3);
    TRI_INTERPOLATION(input,output,bary,normal);
    TRI_INTERPOLATION(input,output,bary,tangent);
    TRI_INTERPOLATION(input,output,bary,color);

    output.normal = normalize(output.normal);
    float3 pt[3];
    for(int i = 0; i < 3; i++)
        pt[i] = input[i].normal * (dot(input[i].vertex.xyz, input[i].normal) - dot(output.vertex.xyz, input[i].normal) - _TessShrink*0.01);
    output.vertex.xyz += (pt[0] * bary.x + pt[1] * bary.y + pt[2] * bary.z) * _TessStrength;

    return vert(output);
}
