struct Shading { // Scalar light levels
	float sunlight;
	float skylight;
	float caustics;
	float torchlight;
	float ambient;
};

struct Lightmap { // Vector light levels with color
	vec3 sunlight;
	vec3 skylight;
	vec3 torchlight;
	vec3 ambient;
	vec3 GI;
};

#include "/lib/Misc/Bias_Functions.glsl"
#include "/lib/Fragment/Sunlight_Shading.fsh"

float GetHeldLight(vec3 viewSpacePosition, vec3 normal, float handMask) {
	mat2x3 lightPos = mat2x3(
	     0.16, -0.05, -0.1,
	    -0.16, -0.05, -0.1);
	
	mat2x3 lightRay = mat2x3(
	    viewSpacePosition - lightPos[0]*0 - gbufferModelView[3].xyz,
	    viewSpacePosition - lightPos[1]*0 - gbufferModelView[3].xyz);
	
	vec2 falloff = rcp(vec2(length2(lightRay[0]), length2(lightRay[1])));
	
	falloff  = vec2(length(lightRay[0]), length(lightRay[1]));
	falloff  = pow2(1.0 / ((1.0 - clamp01(1.0 - falloff / 16.0)*0.9) * 16.0) - 1.0 / 16.0);
	falloff *= clamp01(vec2(dot(normal, lightPos[0]), dot(normal, lightPos[1])) * falloff) * 0.35 + 0.65;
	falloff  = mix(falloff, vec2(1.0), handMask * vec2(greaterThan(viewSpacePosition.x * vec2(1.0, -1.0), vec2(0.0))));
	falloff *= vec2(heldBlockLightValue, heldBlockLightValue2);
	
	return falloff.x + falloff.y;
}

#define SUN_LIGHT_LEVEL     1.0 // [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.1 2.2 2.3 2.4 2.5 2.6 2.7 2.8 2.9 3.0 3.1 3.2 3.3 3.4 3.5 3.6 3.7 3.8 3.9 4.0]
#define SKY_LIGHT_LEVEL     1.0 // [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.1 2.2 2.3 2.4 2.5 2.6 2.7 2.8 2.9 3.0 3.1 3.2 3.3 3.4 3.5 3.6 3.7 3.8 3.9 4.0]
#define AMBIENT_LIGHT_LEVEL 1.0 // [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.1 2.2 2.3 2.4 2.5 2.6 2.7 2.8 2.9 3.0 3.1 3.2 3.3 3.4 3.5 3.6 3.7 3.8 3.9 4.0]
#define TORCH_LIGHT_LEVEL   1.0 // [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.1 2.2 2.3 2.4 2.5 2.6 2.7 2.8 2.9 3.0 3.1 3.2 3.3 3.4 3.5 3.6 3.7 3.8 3.9 4.0]

#define LIGHT_DESATURATION

vec3 Desaturation(vec3 diffuse, vec3 lightmap) {
#ifndef LIGHT_DESATURATION
	return diffuse;
#endif
	
	float desatAmount = clamp01(pow(length(lightmap), 0.07));
	vec3  desatColor  = vec3(diffuse.r + diffuse.g + diffuse.b);
	
	return mix(desatColor, diffuse, desatAmount);
}

vec3 CalculateShadedFragment(vec3 diffuse, Mask mask, float torchLightmap, float skyLightmap, vec4 GI, vec3 normal, float smoothness, mat2x3 position) {
	Shading shading;
	
#ifndef VARIABLE_WATER_HEIGHT
	if (mask.water != isEyeInWater) // Surface is in water
		skyLightmap = 1.0 - clamp01(-(position[1].y + cameraPosition.y - WATER_HEIGHT) / UNDERWATER_LIGHT_DEPTH);
#endif
	
	shading.skylight = pow2(skyLightmap);
	
	shading.caustics = ComputeUnderwaterCaustics(position[1], shading.skylight, mask.water);
	
	shading.sunlight  = GetLambertianShading(normal, lightVector, mask) * shading.skylight;
	shading.sunlight  = ComputeSunlight(position[1], shading.sunlight);
	shading.sunlight *= 3.0 * SUN_LIGHT_LEVEL;
	
	shading.skylight *= mix(shading.caustics * 0.65 + 0.35, 1.0, pow8(1.0 - abs(worldLightVector.y)));
	shading.skylight *= GI.a;
	shading.skylight *= 0.075 * SKY_LIGHT_LEVEL;
	
	shading.torchlight  = pow2(1.0 / ((1.0 - torchLightmap*0.9) * 16.0) - 1.0 / 16.0) * 16.0;
	shading.torchlight += GetHeldLight(position[0], normal, mask.hand);
	shading.torchlight += mask.emissive * 5.0;
	shading.torchlight *= GI.a;
	shading.torchlight *= 0.05 * TORCH_LIGHT_LEVEL;
	
	shading.ambient  = 0.5 + (1.0 - eyeBrightnessSmooth.g / 240.0) * 3.0;
	shading.ambient += nightVision * 50.0;
	shading.ambient *= GI.a * 0.5 + 0.5;
	shading.ambient *= 0.0002 * AMBIENT_LIGHT_LEVEL;
	
	
	Lightmap lightmap;
	
	lightmap.sunlight = shading.sunlight * shading.caustics * sunlightColor;
	
	lightmap.skylight = shading.skylight * sqrt(skylightColor);
	
	lightmap.GI = GI.rgb * GI.a * sunlightColor;
	
	lightmap.ambient = vec3(shading.ambient);
	
	lightmap.torchlight = shading.torchlight * 10.0 * vec3(0.5, 0.22, 0.05);
	
	lightmap.skylight *= clamp01(1.0 - dot(lightmap.GI, vec3(1.0)) / 6.0);
	
	
	vec3 composite  = lightmap.sunlight + lightmap.skylight + lightmap.torchlight + lightmap.GI + lightmap.ambient;
	     composite *= Desaturation(diffuse, composite);
	
	return composite;
}