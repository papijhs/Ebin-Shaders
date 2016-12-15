struct Shading { // Scalar light levels
	float sunlight;
	float skylight;
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
	const mat2x3 lightPos = mat2x3(
	     0.16, -0.05, -0.1,
	    -0.16, -0.05, -0.1);
	
	mat2x3 lightRay = mat2x3(
	    viewSpacePosition - lightPos[0],
	    viewSpacePosition - lightPos[1]);
	
	vec2 falloff = vec2(inversesqrt(length2(lightRay[0])), inversesqrt(length2(lightRay[1])));
	
	falloff *= clamp01(vec2(dot(normal, lightPos[0] * falloff[0]), dot(normal, lightPos[1] * falloff[1]))) * 0.35 + 0.65;
	
	vec2 hand  = max0(falloff - 0.0625);
	     hand  = mix(hand, vec2(2.0), handMask * vec2(greaterThan(viewSpacePosition.x * vec2(1.0, -1.0), vec2(0.0))));
	     hand *= vec2(heldBlockLightValue, heldBlockLightValue2) / 16.0;
	
	return hand.x + hand.y;
}

vec3 CalculateShadedFragment(Mask mask, float torchLightmap, float skyLightmap, vec3 GI, vec3 normal, vec3 vertNormal, float smoothness, mat2x3 position) {
	Shading shading;
	
	shading.sunlight  = GetLambertianShading(normal, mask) * skyLightmap;
	shading.sunlight  = ComputeSunlight(position[1], shading.sunlight, vertNormal);
	
	
	shading.torchlight  = 1.0 - pow(clamp01(torchLightmap - 0.075), 4.0);
	shading.torchlight  = 1.0 / pow(shading.torchlight, 2.0) - 1.0;
	shading.torchlight += GetHeldLight(position[0], normal, mask.hand);
	
	shading.skylight = pow(skyLightmap, 2.0);
	
#ifndef GI_ENABLED
	shading.skylight *= 1.5;
#endif
	
	shading.ambient  = 1.0 + (1.0 - eyeBrightnessSmooth.g / 240.0) * 1.7;
	shading.ambient += mask.nightVision * 50.0;
	
	
	Lightmap lightmap;
	
	lightmap.sunlight = shading.sunlight * sunlightColor;
	
	lightmap.skylight = shading.skylight * pow(skylightColor, vec3(0.5));
	
	
	GI = hsv(GI);
	GI.g = sqrt(GI.g);
	GI = rgb(GI);
	
	lightmap.GI = GI * sunlightColor;
	
	lightmap.ambient = vec3(shading.ambient);
	
	lightmap.torchlight = shading.torchlight * vec3(0.7, 0.3, 0.1);
	
	lightmap.skylight *= clamp01(1.0 - dot(lightmap.GI, vec3(1.0 / 3.0)) * 0.5);
	
	return vec3(
	    lightmap.sunlight   * 16.0  * SUN_LIGHT_LEVEL
	+   lightmap.skylight   * 1.8   * SKY_LIGHT_LEVEL * SKY_BRIGHTNESS
	+   lightmap.GI         * 1.0
	+   lightmap.ambient    * 0.015 * AMBIENT_LIGHT_LEVEL
	+   lightmap.torchlight * 6.0   * TORCH_LIGHT_LEVEL
	    );
}
