struct Shading {      // Contains scalar light levels without any color
	float normal;     // Coefficient of light intensity based on the dot product of the normal vector and the light vector
	float sunlight;
	float skylight;
	float caustics;
	float torchlight;
	float ambient;
};

struct Lightmap {    // Contains vector light levels with color
	vec3 sunlight;
	vec3 skylight;
	vec3 ambient;
	vec3 torchlight;
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

vec3 CalculateShadedFragment(Mask mask, float torchLightmap, float skyLightmap, vec3 GI, float AO, vec3 normal, float smoothness, vec4 ViewSpacePosition) {
	Shading shading;
	
	float F0 = undefF0;
	F0 = F0Calc(F0, mask.metallic);
	
	#ifndef PBR
		shading.normal = GetDiffuseShading(ViewSpacePosition, normal, 1.0 - smoothness, mask);
	#else
		float diffuseLighting = diffuse(F0, ViewSpacePosition, normal, 1.0 - pow2(smoothness));
		
		float scRange = smoothstep(0.25, 0.45, F0);
		float  dielectric = diffuseLighting;
	  float  metal = max0(dot(normal, lightVector));

		shading.normal = mix(dielectric, metal, scRange);
	#endif
	
	vec3 SubSurfaceColor = vec3(1.0);
	if(mask.leaves > 0.5 || mask.grass > 0.5) {
		float SubSurfaceDiffusion = GetGGXSubsurfaceDiffuse(ViewSpacePosition, normal, 1.0 - smoothness);
		SubSurfaceDiffusion = SubSurfaceDiffusion * (1.0 - mask.grass       ) + mask.grass       ;
		SubSurfaceDiffusion = SubSurfaceDiffusion * (1.0 - mask.leaves * 0.5) + mask.leaves * 0.5;
		
		show(SubSurfaceDiffusion);
		SubSurfaceColor = SubSurfaceDiffusion * vec3(1.0, 1.2, 1.0);
		shading.normal = SubSurfaceDiffusion;
	}
	
	shading.sunlight  = shading.normal;
	shading.sunlight *= pow2(skyLightmap);
	shading.sunlight  = ComputeShadows(ViewSpacePosition, shading.sunlight);
	
	#if defined composite1
		// Underwater light caustics
	#endif
	
	
	shading.torchlight = 1.0 - pow(clamp01(torchLightmap - 0.075), 4.0);
	shading.torchlight = 1.0 / pow(shading.torchlight, 2.0) - 1.0;
	
	shading.skylight = pow(skyLightmap, 2.0);
	
#ifndef GI_ENABLED
	shading.skylight /= 0.7;
#endif
	
	
	shading.ambient = 1.0 + (1.0 - eyeBrightnessSmooth.g / 240.0) * 1.3;
	
	
	Lightmap lightmap;
	
	lightmap.sunlight = shading.sunlight * sunlightColor * SubSurfaceColor * pow(AO, 0.7);
	
	lightmap.skylight = shading.skylight * pow(skylightColor, vec3(0.5)) * AO;
	
	
	
	lightmap.GI = GI * sunlightColor * AO;
	
	lightmap.ambient = shading.ambient * vec3(AO);
	
	lightmap.torchlight = shading.torchlight * vec3(0.7, 0.3, 0.1) * pow(AO, 0.7);
	
	
	return vec3(
	    lightmap.sunlight   * 6.0    * SUN_LIGHT_LEVEL
	+   lightmap.skylight   * 0.7    * SKY_LIGHT_LEVEL
	+   lightmap.GI         * 1.0
	+   lightmap.ambient    * 0.0175 * AMBIENT_LIGHT_LEVEL
	+   lightmap.torchlight * 3.0    * TORCH_LIGHT_LEVEL
	    );
}
