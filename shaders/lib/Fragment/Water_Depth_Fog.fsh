vec3 WaterFog(vec3 color, vec3 normal, vec3 viewSpacePosition0, vec3 viewSpacePosition1) {
#ifdef CLEAR_WATER
	return color;
#endif
	
	viewSpacePosition1 *= 1 - isEyeInWater;
	vec3 viewVector = -normalize(viewSpacePosition1);
	
	float waterDepth = distance(viewSpacePosition1, viewSpacePosition0); // Depth of the water volume

	vec3 skyLightVector = normalize(reflect(viewSpacePosition1, normal));

	float NoL = clamp(dot(normal, skyLightVector), 0.001, 1.0);
    float NoV = clamp(dot(normal, viewVector), 0.001, 1.0);

	float BouguerLambert = (1.0 / NoV + 1.0 / NoL);
	if (isEyeInWater > 0.0) BouguerLambert = 1.0;

	vec3 fogAccum = exp(-vec3(0.65, 0.94, 1.0) * waterDepth * BouguerLambert * 0.1); // Beer's Law

	vec3 waterDepthColors = sunlightColor * skylightColor * mix(0.2, 1.0, eyeBrightnessSmooth.g / 240.0);
	
	color *= pow(vec3(0.65, 0.94, 1.0) * skylightColor, vec3(waterDepth) * 0.2);
	color  = mix(waterDepthColors, color, clamp01(fogAccum));
	
	return color;
}
