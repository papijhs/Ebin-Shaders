vec3 fresnel(vec3 f0, float f90, float LoH) {
    return f0 + (f90 - f0) * pow(1.0 - LoH, 5.0);
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

    return  alpha2 / (PI * denom * denom);
}
vec3 BlendMaterial(vec3 Kdiff, vec3 Kspec, vec3 diffuseColor, vec3 f0) {
  vec3 scRange = smoothstep(vec3(0.25), vec3(0.45), f0);
  vec3  dielectric = diffuseColor + Kspec;
  vec3  metal = diffuseColor * Kspec;

  return mix(dielectric, metal, scRange);
}

vec3 BRDF(vec3 L, vec3 V, vec3 N, float roughness, vec3 f0) {
    roughness = max(roughness, 0.05);
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
