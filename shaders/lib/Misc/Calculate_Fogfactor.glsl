float CalculateFogFactor(vec3 position, float power) {
#ifndef FOG_ENABLED
	return 0.0;
#endif
	
	float fogFactor  = length(position);
		  fogFactor  = max0(fogFactor - gl_Fog.start);
		  fogFactor /= far - gl_Fog.start;
		  fogFactor  = pow(fogFactor, power);
		  fogFactor  = clamp01(fogFactor);
	
	return fogFactor;
}

float CalculateFogFactor(vec3 position, float power, float skyMask) {
#ifndef FOG_ENABLED
	return skyMask;
#endif
	
	float fogFactor  = length(position);
		  fogFactor  = max0(fogFactor - gl_Fog.start);
		  fogFactor /= far - gl_Fog.start;
		  fogFactor  = pow(fogFactor, power);
		  fogFactor  = clamp01(fogFactor);
	
	return fogFactor;
}
