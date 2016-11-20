float GetLambertianShading(vec3 normal) {
	return clamp01(dot(normal, lightVector));
}

float GetLambertianShading(vec3 normal, Mask mask) {
	float shading = clamp01(dot(normal, lightVector));
	      shading = mix(shading, 1.0, mask.grass);
	      shading = mix(shading, 1.0, mask.leaves);
	
	return shading;
}

#if SHADOW_TYPE == 2 && defined composite1
	float ComputeShadows(vec3 shadowPosition, float biasCoeff) {
		float spread = (1.0 - biasCoeff) / shadowMapResolution;
		
		cfloat range       = 1.0;
		cfloat interval    = 1.0;
		cfloat sampleCount = pow(range / interval * 2.0 + 1.0, 2.0);
		
		float sunlight = 0.0;
		
		for (float y = -range; y <= range; y += interval)
			for (float x = -range; x <= range; x += interval)
				sunlight += shadow2D(shadow, vec3(shadowPosition.xy + vec2(x, y) * spread, shadowPosition.z)).x;
		
		return sunlight / sampleCount;
	}
#else
	#define ComputeShadows(shadowPosition, biasCoeff) shadow2D(shadow, shadowPosition).x
#endif

float ComputeSunlight(vec3 viewSpacePosition, float sunlightCoeff, vec3 vertNormal) {
	if (sunlightCoeff <= 0.01) return 0.0;
	
	float biasCoeff;
	
	vec3 shadowPosition = BiasShadowProjection(projMAD(shadowProjection, transMAD(shadowViewMatrix, viewSpacePosition + gbufferModelViewInverse[3].xyz)), biasCoeff) * 0.5 + 0.5;
	
	if (any(greaterThan(abs(shadowPosition.xyz - 0.5), vec3(0.5)))) return 1.0;
	
	float sunlight = ComputeShadows(shadowPosition, biasCoeff);
	
	return sunlightCoeff * pow2(sunlight);
}
