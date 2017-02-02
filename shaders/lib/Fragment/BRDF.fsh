struct MatData { // Vector light levels with color
	float roughness;
    float smoothness;
	float AO;
	vec3 f0;
};

MatData unpackMatData(in vec3 compressedData) {
    MatData mat;

	float smoothness = Decode4x8F(compressedData.r).g;
	vec4 unpackedf0AO = Decode4x8F(compressedData.b);

	mat.roughness = 1.0 - smoothness;
	mat.AO = unpackedf0AO.a;
	mat.f0 = unpackedf0AO.rgb;

    return mat;
}


vec3 SunMRP(vec3 normal, vec3 viewVector, vec3 lightVector) {
  vec3 R = reflect(viewVector, normal);
  float angularRadius = 3.14 * 0.54 / 180.0;

  vec3 D = lightVector;
  float d = cos(angularRadius);
  float r = sin(angularRadius);

  float DdotR = dot(D, R);
  vec3 S = R - DdotR * D;

  return (DdotR < d) ? normalize(d * D + normalize(S) * r) : R;
}

vec2 Hammersley(uint i, uint N)  {
    float ri = bitfieldReverse(i) * 2.3283064365386963e-10f;
    return vec2(float(i) / float(N), ri);
}

vec3 fresnel(vec3 f0, float f90, float LoH) {
    return f0 + (f90 - f0) * pow(1.0 - LoH, 5.0);
}

float computeSpecularOcclusion(float AO, float NoV, float roughness) {
    return clamp01(pow(NoV + AO, exp2(-16.0f * roughness - 1.0f)) - 1.0f + AO);
}

float Vis_SmithJointApprox(float roughness, float NoV, float NoL) {
    float  alpha2 = roughness * roughness;

    float  Lambda_GGXV = NoL * sqrt((-NoV * alpha2 + NoV) * NoV + alpha2);
    float  Lambda_GGXL = NoV * sqrt((-NoL * alpha2 + NoL) * NoL + alpha2);

    return  0.5f / (Lambda_GGXV + Lambda_GGXL);
}

float GGX(float NoH, float alpha) {
    float alpha2 = alpha * alpha;
    float denom = (NoH * alpha2 - NoH) * NoH + 1.0;

    return  alpha2 / (denom * denom);
}
vec3 BlendMaterial(vec3 Kdiff, vec3 Kspec, vec3 diffuseColor, vec3 f0) {
  vec3 scRange = smoothstep(vec3(0.25), vec3(0.45), f0);
  vec3  dielectric = diffuseColor + Kspec;
  vec3  metal = diffuseColor * Kspec;

  return dielectric;
}

float DisneyDiffuse(vec3 V, vec3 L, vec3 N, float linearRoughness) {
    vec3 H = normalize(V + L);
    float NoV = abs(dot(N, V));
    float NoL = clamp01(dot(N, L));
    float LoH = clamp01(dot(L, H));

    float energyBias = mix(0.0, 0.5,  linearRoughness);
    float energyFactor = mix(1.0, 1.0 / 1.51,  linearRoughness);
    float fd90 = energyBias + 2.0 * LoH*LoH * linearRoughness;

    vec3 f0 = vec3(1.0);
    float lightScatter = fresnel(f0, fd90 , NoL).r;
    float viewScatter = fresnel(f0, fd90 , NoV).r;

    return lightScatter * viewScatter * energyFactor;
}

vec3 BRDF(vec3 L, vec3 V, vec3 N, float roughness, vec3 f0) {
    roughness = clamp(roughness, 0.01, 1.0);
    vec3 H = normalize(V + L);

    float NoV = abs(dot(N, V)) + 1e-5;
    float VoH = clamp01(dot(V, H));
    float NoH = clamp01(dot(N, H));
    float NoL = clamp01(dot(N, L));
 
    vec3 fresnel = fresnel(vec3(f0), 1.0, VoH);
    float Vis = Vis_SmithJointApprox(roughness, NoV, NoL);
    float distribution = GGX(NoH, roughness);

    vec3 specular = distribution * fresnel * Vis / PI;

    return specular * NoL;
}

float BSDF(vec3 L, vec3 D, vec3 V, vec3 N, float roughness, float f0) {
    roughness = clamp(roughness, 0.01, 1.0);
    vec3 H = normalize(V + L);

    float NoV = abs(dot(N, V)) + 1e-5;
    float VoH = clamp01(dot(V, H));
    float NoH = clamp01(dot(N, H));
    float NoL = clamp01(dot(N, L));
 
    float fresnel = fresnel(vec3(f0), 1.0, VoH).r;
    float Vis = Vis_SmithJointApprox(roughness, NoV, NoL);
    float distribution = GGX(NoH, roughness);

    float specular = distribution * fresnel * Vis / PI;
    float diffuse = DisneyDiffuse(V, D, N, pow2(roughness)) / PI;

    return diffuse + specular;
}

vec3 importanceSampleCosDir(vec2 u, vec3 N) {
    vec3 upVector = abs(N.z) < 0.999 ? vec3(0,0,1) : vec3(1,0,0);
    vec3 tangentX = normalize(cross(upVector, N));
    vec3 tangentY = cross(N, tangentX);

    float r = sqrt(u.x);
    float phi = u.y * PI * 2.0;

    vec3 L = vec3(r * cos(phi), r * sin(phi), sqrt(max(0.0, 1.0 - u.x)));
         L = normalize(tangentX * L.x + tangentY * L.y + N * L.z);

    return L;
}

vec3 importanceSampleGGX(vec2 Xi, float roughness, vec3 N) {
    float alpha = pow2(roughness);

    float Phi = 2.0 * PI * Xi.x;
    float cosTheta = sqrt((1.0 - Xi.y) / (1.0 + (pow2(alpha) - 1.0) * Xi.y));
    float sinTheta = sqrt(1.0 - pow2(cosTheta));

    vec3 H;
    H.x = sinTheta * cos(Phi);
    H.y = sinTheta * sin(Phi);
    H.z = cosTheta;

    vec3 UpVector = abs(N.z) < 0.999 ? vec3(0, 0, 1) : vec3(1, 0, 0);
    vec3 TangentX = normalize(cross(UpVector, N));
    vec3 TangentY = cross(N, TangentX);

    return normalize(TangentX * H.x + TangentY * H.y + N * H.z);
}

#if ShaderStage == 1 || ShaderStage == 2
vec3 integrateSpecularIBL(vec3 V, vec3 N, float roughness, vec3 f0, out float NoV) {
    NoV = clamp01(dot(V, N));
    vec3 accum = vec3(0.0);
    uint samples = 32u;

    for(uint i = 0u; i < samples; i++) {
        vec2 Xi = Hammersley(i, samples);

        vec3 L, H;

        H = importanceSampleGGX(Xi, roughness, N);
        L = normalize(-reflect(V, H));

        float NoL = clamp01(dot(N, L));
        float VoH = clamp01(dot(V, H));
        float NoH = clamp01(dot(N, H));

        if(NoL > 0.0) {
            float GVis = Vis_SmithJointApprox(roughness, NoV, NoL);
            float Fc = pow(1.0 - VoH, 5.0);
            vec3 F = (1.0 - Fc) * f0 + Fc;

            vec3 sky = getSkyProjected(normalize(mat3(gbufferModelViewInverse) * L), 0) * NoL;
            accum += sky * F * GVis / PI;
        }
    }

    return accum / float(samples);
}

vec3 integrateDiffuseIBL(vec3 V, vec3 N, float roughness, vec3 f0) {
    float NoV = clamp01(dot(V, N));
    vec3 accum = vec3(0.0);
    uint samples = 32u;

    for(uint i = 0u; i < samples; i++) {
        vec2 Xi = Hammersley(i, samples);

        vec3 L, H;

        H = importanceSampleCosDir(Xi, N);
        L = normalize(-reflect(V, H));

        float NoL = clamp01(dot(N, L));
        float VoH = clamp01(dot(V, H));
        float NoH = clamp01(dot(N, H));

        if(NoL > 0.0) {
            vec3 sky = getSkyProjected(normalize(mat3(gbufferModelViewInverse) * L), 6);
            accum += sky * (DisneyDiffuse(V, L, N, roughness) * NoL) / PI;
        }
    }
    return accum / float(samples);
}
#endif