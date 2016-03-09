#define FOGPOW 2.0

float CalculateFogFactor(in vec4 position, in float power) {
	float fogFactor = length(position.xyz);
		  fogFactor = max(fogFactor - gl_Fog.start, 0.0);
		  fogFactor /= far - gl_Fog.start;
		  fogFactor = pow(fogFactor, power);
		  fogFactor = clamp(fogFactor, 0.0, 1.0);
	
	return fogFactor;
}