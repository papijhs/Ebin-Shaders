float GetLambertianShading(vec3 normal, Mask mask) {
	float shading = max0(dot(normal, lightVector));
	      shading = shading * (1.0 - mask.grass       ) + mask.grass       ;
	      shading = shading * (1.0 - mask.leaves * 0.5) + mask.leaves * 0.5;
	
	return shading;
}

#if ShaderStage >= 1
#include "/lib/Fragment/Reflectance_Models.fsh"

float GetNormalShading(vec3 normal, Mask mask, vec3 viewSpacePosition, float roughness) {
	float directDiffuse;
	float lambert = max0(dot(normal, lightVector));
	
	#ifndef PBR
		directDiffuse = lambert;
	#else
		bool isSS = mask.grass > 0.5 || mask.leaves > 0.5;
		
		if(isSS) {
			directDiffuse = GetGGXSubsurfaceDiffuse(viewSpacePosition, normal, roughness);
		} else {
			float F0 = undefF0; //Grab the default F0
			      F0 = F0Calc(F0, mask.metallic); //Apply F0 transformation to correct it for metals
						
			directDiffuse = diffuse(F0, viewSpacePosition, normal, roughness);
						
			float scRange = smoothstep(0.25, 0.45, F0); //Apply a blend for materials to remove diffuse from metals
			float  dielectric = directDiffuse;
			float  metal = lambert;
			
			directDiffuse = mix(dielectric, metal, scRange);
		}
	#endif
	
	directDiffuse = directDiffuse * (1.0 - mask.grass       ) + mask.grass       ;
	directDiffuse = directDiffuse * (1.0 - mask.leaves * 0.5) + mask.leaves * 0.5;
	
	return directDiffuse;
}

#else
#define GetNormalShading(a, b, c, d) GetLambertianShading(a, b)
#endif
