#ifndef PBR
void ComputeReflectedLight(inout vec3 color, mat2x3 position, vec3 normal, float smoothness, float skyLightmap, Mask mask) {
	if (isEyeInWater == 1) return;
	
	float alpha = (pow2(min1(1.0 + dot(normalize(position[0]), normal))) * 0.99 + 0.01) * smoothness;
	
	if (length(alpha) < 0.005) return;
	
	mat2x3 refRay;
	refRay[0] = reflect(position[0], normal);
	refRay[1] = mat3(gbufferModelViewInverse) * refRay[0];
	
	float firstStepSize = mix(1.0, 30.0, pow2(length(position[1].xz) / 144.0));
	vec3  reflectedCoord;
	vec3  reflectedViewSpacePosition;
	vec3  reflection;
	
	float sunlight = ComputeShadows(position[1], 1.0) * GetLambertianShading(normal);
	
	vec3 reflectedSky = CalculateSky(refRay, position[1], 1.0, true, sunlight);
	
	vec3 offscreen = reflectedSky * skyLightmap;
	
	if (!ComputeRaytracedIntersection(position[0], normalize(refRay[0]), firstStepSize, 1.5, 30, 1, reflectedCoord, reflectedViewSpacePosition))
		reflection = offscreen;
	else {
		reflection = GetColor(reflectedCoord.st);
		
		reflection = mix(reflection, reflectedSky, CalculateFogFactor(reflectedViewSpacePosition, FOG_POWER));
		
		#ifdef REFLECTION_EDGE_FALLOFF
			float angleCoeff = clamp(pow(dot(vec3(0.0, 0.0, 1.0), normal) + 0.15, 0.25) * 2.0, 0.0, 1.0) * 0.2 + 0.8;
			float dist       = length8(abs(reflectedCoord.xy - vec2(0.5)));
			float edge       = clamp(1.0 - pow2(dist * 2.0 * angleCoeff), 0.0, 1.0);
			reflection       = mix(reflection, offscreen, pow(1.0 - edge, 10.0));
		#endif
	}
	
	color = mix(color, reflection, alpha);
}

#else

void ComputeReflectedLight(inout vec3 color, mat2x3 position, vec3 normal, float smoothness, float skyLightmap, Mask mask) {
	if (isEyeInWater == 1) return;
	
	float firstStepSize = mix(1.0, 30.0, pow2(length(position[1].xz) / 144.0));
	vec3  reflectedCoord;
	vec3  reflectedViewSpacePosition;
	vec3  reflection;
	
	float roughness = 1.0 - smoothness;
	float alpha = pow2(roughness);
	float alpha2 = pow2(alpha);
	
	float F0 = undefF0;
	F0 = F0Calc(F0, mask.metallic);
	
	vec3 viewVector = -normalize(position[0]);
	vec3 worldVector = normalize(position[1]);
	
	float sunlight = ComputeShadows(position[0], 1.0);
	sunlight *= dot(normal, lightVector);
	skyLightmap = clamp01(pow(skyLightmap, 4));
	
	vec3 upVector = abs(normal.z) < 0.999 ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0);
	vec3 tanX = normalize(cross(upVector, normal));
	vec3 tanY = cross(normal, tanX);

	for (uint i = 0u; i < PBR_RAYS; i++) {
		vec2 epsilon = Hammersley(i + 1, PBR_RAYS + 1);
		vec3 BRDFSkew = skew(epsilon, alpha);
		vec3 microFacetNormal = normalize(BRDFSkew.x * tanX + BRDFSkew.y * tanY + BRDFSkew.z * normal);

		mat2x3 refRay;
		refRay[0] = reflect(position[0], microFacetNormal);
		refRay[1] = transMAD(gbufferModelViewInverse, refRay[0]);

		float raySpecular = specularBRDF(normalize(refRay[0]), microFacetNormal, F0, viewVector, sqrt(roughness));

		vec3 reflectedAmbient = CalculateSky(refRay, position[1], 1.0, true, sunlight);

		reflectedAmbient *= skyLightmap * raySpecular;
		reflectedAmbient += mask.metallic * (1.0 - skyLightmap) * 0.15;
		
		if (!ComputeRaytracedIntersection(position[0], normalize(refRay[0]), firstStepSize, 1.25, 25, 1, reflectedCoord, reflectedViewSpacePosition)) {
			reflection += reflectedAmbient;
		} else {
			vec3 colorSample = GetColorLod(reflectedCoord.st, roughness * 4.0);
			colorSample = mix(colorSample, reflectedAmbient, CalculateFogFactor(reflectedViewSpacePosition, FOG_POWER));

			reflection += colorSample * raySpecular;
		}
	}

	reflection /= float(PBR_RAYS);

	reflection = BlendMaterial(color, reflection, F0);

	color = max0(reflection);
}
#endif
