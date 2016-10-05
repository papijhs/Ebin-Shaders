struct Shading {      // Contains scalar light levels without any color
	float sunlight;
	float skylight;
	float torchlight;
	float ambient;
};

struct Lightmap {    // Contains vector light levels with color
	vec3 sunlight;
	vec3 skylight;
	vec3 torchlight;
	vec3 ambient;
	vec3 GI;
};


#include "/lib/Misc/Bias_Functions.glsl"
#include "/lib/Fragment/Sunlight/GetSunlightShading.fsh"

#if SHADOW_TYPE == 3 && defined composite1
	#include "/lib/Fragment/Sunlight/ComputeVariablySoftShadows.fsh"
#elif SHADOW_TYPE == 2 && defined composite1
	#include "/lib/Fragment/Sunlight/ComputeUniformlySoftShadows.fsh"
#else
	#include "/lib/Fragment/Sunlight/ComputeHardShadows.fsh"
#endif

#if defined composite1
// Underwater light caustics
#endif



float GetHeldLight(vec3 viewSpacePosition, vec3 normal, float handMask) {
	mat2x3 lightPos = mat2x3(
	     0.16, -0.05, -0.1,
	    -0.16, -0.05, -0.1);
	
	mat2x3 lightRay = mat2x3(
	    viewSpacePosition - lightPos[0],
	    viewSpacePosition - lightPos[1]);
	
	vec2 falloff = vec2(inversesqrt(length2(lightRay[0])), inversesqrt(length2(lightRay[1])));
	
	falloff *= max0(vec2(dot(normal, lightPos[0] * falloff[0]), dot(normal, lightPos[1] * falloff[1]))) * 0.35 + 0.65;
	
	vec2 hand  = max0(falloff - 0.0625);
	     hand  = mix(hand, vec2(2.0), handMask * vec2(greaterThan(viewSpacePosition.x * vec2(1.0, -1.0), vec2(0.0))));
	     hand *= heldBlockLightValue / 16.0;
	
	return hand.x + hand.y;
}

vec3 CalculateShadedFragment(Mask mask, float torchLightmap, float skyLightmap, vec3 GI, vec3 normal, float smoothness, vec3 viewSpacePosition) {
	Shading shading;
	
	shading.sunlight  = GetNormalShading(normal, mask, viewSpacePosition, 1.0 - smoothness);
	shading.sunlight *= pow2(skyLightmap);
	shading.sunlight  = ComputeShadows(viewSpacePosition, shading.sunlight);
	
	
	shading.torchlight  = 1.0 - pow(clamp01(torchLightmap - 0.075), 4.0);
	shading.torchlight  = 1.0 / pow(shading.torchlight, 2.0) - 1.0;
	shading.torchlight += GetHeldLight(viewSpacePosition, normal, mask.hand);
	
	shading.skylight = pow(skyLightmap, 2.0);
	
#ifndef GI_ENABLED
	shading.skylight /= 0.7;
#endif
	
	
	shading.ambient = 1.0 + (1.0 - eyeBrightnessSmooth.g / 240.0) * 1.3;
	
	
	Lightmap lightmap;
	
	lightmap.sunlight = shading.sunlight * sunlightColor;
	
	lightmap.skylight = shading.skylight * pow(skylightColor, vec3(0.5));
	
	
	
	lightmap.GI = GI * sunlightColor;
	
	lightmap.ambient = vec3(shading.ambient);
	
	lightmap.torchlight = shading.torchlight * vec3(0.7, 0.3, 0.1);
	
	
	return vec3(
	    lightmap.sunlight   * 6.0    * SUN_LIGHT_LEVEL
	+   lightmap.skylight   * 0.7    * SKY_LIGHT_LEVEL
	+   lightmap.GI         * 1.0
	+   lightmap.ambient    * 0.0175 * AMBIENT_LIGHT_LEVEL
	+   lightmap.torchlight * 3.0    * TORCH_LIGHT_LEVEL
	    );
}
