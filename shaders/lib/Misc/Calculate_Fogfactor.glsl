float CalculateFogFactor(vec3 position, const float power) {
#ifndef FOG_ENABLED
	return 0.0;
#endif
	
	float fogFactor  = length(position);
		  fogFactor  = max0(fogFactor - gl_Fog.start*0);
		  fogFactor /= far*2.0 - gl_Fog.start*0;
		  fogFactor  = pow(fogFactor, power);
		  fogFactor  = clamp01(fogFactor);
	
	fogFactor = 1.0 - exp( -max0(length(position)) / far / 8.0);
	
	return fogFactor;
}

float CalculateFogFactor(vec3 position, const float power, float skyMask) {
#ifndef FOG_ENABLED
	return skyMask;
#endif
	
	if (skyMask > 0.5) return skyMask;
	
	return CalculateFogFactor(position, power);
}
