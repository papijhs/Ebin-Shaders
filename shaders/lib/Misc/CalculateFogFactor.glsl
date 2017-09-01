//#define FOG_ENABLED
#define FOG_POWER 2.0 // [1.0 1.5 2.0 2.5 3.0 3.5 4.0 4.5 5.0 5.5 6.0 6.5 7.0 7.5 8.0]

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
