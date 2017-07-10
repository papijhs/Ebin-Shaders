//#define FOG_ENABLED
#define FOG_POWER 3.0 // [1.0 2.0 3.0 4.0 6.0 8.0]

float CalculateFogFactor(vec3 position) {
#ifndef FOG_ENABLED
	return 0.0;
#endif
	
	float fogFactor  = length(position);
		  fogFactor  = max0(fogFactor - gl_Fog.start);
		  fogFactor /= far - gl_Fog.start;
		  fogFactor  = pow(fogFactor, FOG_POWER);
		  fogFactor  = clamp01(fogFactor);
	
	return fogFactor;
}

float CalculateFogFactor(vec3 position, float skyMask) {
#ifndef FOG_ENABLED
	return skyMask;
#endif
	
	float fogFactor  = length(position);
		  fogFactor  = max0(fogFactor - gl_Fog.start);
		  fogFactor /= far - gl_Fog.start;
		  fogFactor  = pow(fogFactor, FOG_POWER);
		  fogFactor  = clamp01(fogFactor);
	
	return fogFactor;
}
