#if !defined CALCULATEFOGFACTOR_GLSL
#define CALCULATEFOGFACTOR_GLSL

float CalculateFogfactor(vec3 position) {
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

#endif
