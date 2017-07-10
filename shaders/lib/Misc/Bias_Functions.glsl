const int   shadowMapResolution = 2048;  // [1024 2048 3072 4096 8192]
const float shadowDistance      = 140;   // [70 140 280]
const float sunPathRotation     = -40.0; // [-60.0 -50.0 -40.0 -30.0 -20.0 -10.0 0.0 10.0 20.0 30.0 40.0 50.0 60.0]

#define SHADOW_MAP_BIAS 0.80     // [0.00 0.60 0.70 0.80 0.85 0.90]
//#define LIMIT_SHADOW_DISTANCE

#define zShrink 4.0

float GetDistanceCoeff(vec3 position) {
#ifndef LIMIT_SHADOW_DISTANCE
	return 0.0;
#endif
	
	return pow2(clamp01(length(position) / shadowDistance * 10.0 - 9.0));
}

float GetShadowBias(vec2 shadowProjection) {
	float dist = length(shadowProjection);
	
#ifndef LIMIT_SHADOW_DISTANCE
	dist *= 1.165;
#endif
	
	return mix(1.0, dist, SHADOW_MAP_BIAS);
}

vec2 BiasShadowMap(vec2 shadowProjection, out float biasCoeff) {
	biasCoeff = GetShadowBias(shadowProjection);
	return shadowProjection / biasCoeff;
}

vec2 BiasShadowMap(vec2 shadowProjection) {
	return shadowProjection / GetShadowBias(shadowProjection);
}

vec3 BiasShadowProjection(vec3 position, out float biasCoeff) {
	biasCoeff = GetShadowBias(position.xy);
	return position / vec3(vec2(biasCoeff), zShrink); // Apply bias to position.xy, shrink z-buffer
}

vec3 BiasShadowProjection(vec3 position) {
	return position / vec3(vec2(GetShadowBias(position.xy)), zShrink);
}
