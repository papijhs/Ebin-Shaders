//#define CLEAR_WATER

vec3 WaterFog(vec3 color, vec3 position0, vec3 position1) {
#ifdef CLEAR_WATER
	return color;
#endif
	
	position1 *= 1.0 - isEyeInWater;
	
	float waterDepth = distance(position0, position1) * 0.3; // Depth of the water volume
	
	float fogAccum = exp(-waterDepth * 0.1); // Beer's Law
	
	vec3 waterDepthColors = vec3(0.015, 0.04, 0.098) * sunlightColor * mix(0.2, 1.0, eyeBrightnessSmooth.g / 240.0);
	
	color *= pow(vec3(0.1, 0.5, 0.8), vec3(waterDepth) * 0.8);
	color  = mix(waterDepthColors, color, clamp01(fogAccum));
	
	return color;
}
