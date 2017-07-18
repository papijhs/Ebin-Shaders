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

//#define WATER_CAUSTICS
#include "/UserProgram/WaterHeight.glsl"
//#define VARIABLE_WATER_HEIGHT
#define UNDERWATER_LIGHT_DEPTH 16 // [4 8 16 32 64 65536]

#if defined composite1
#include "/lib/Fragment/Water_Waves.fsh"

float CalculateWaterCaustics(vec3 worldPos, float skyLightmap, float waterMask) {
#ifndef WATER_CAUSTICS
	return 1.0;
#endif
	
	if (skyLightmap <= 0.0 || WAVE_MULT == 0.0 || isEyeInWater == waterMask) return 1.0;
	
	SetupWaveFBM();
	
	worldPos += cameraPosition + gbufferModelViewInverse[3].xyz - vec3(0.0, 1.62, 0.0);
	
	float verticalDist = min(abs(worldPos.y - WATER_HEIGHT), 2.0);
	
	vec3 flatRefractVector  = refract(-worldLightVector, vec3(0.0, 1.0, 0.0), 1.0 / 1.3333);
	     flatRefractVector *= verticalDist / flatRefractVector.y;
	
	vec3 lookupCenter = worldPos + flatRefractVector;
	
	vec2 coord = lookupCenter.xz + lookupCenter.y;
	
	cfloat distanceThreshold = 0.15;
	
	float caustics = 0.0;
	
	vec3 r; // RIGHT height sample to rollover between columns
	vec3 a; // .x = center      .y = top      .z = right
	mat4x2[4] p;
	
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) { // 3x3 sample matrix. Starts bottom-left and immediately goes UP
			vec2 offset = vec2(x, y) * 0.1;
			
			// Generate heights for wave normal differentials. Lots of math & sample reuse happening
			if (x == -1 && y == -1) a.x = GetWaves(coord + offset, p[0]); // If bottom-left-position, generate the height & save FBM coords
			else if (x == -1)       a.x = a.y;                            // If left-column, reuse TOP sample from previous iteration
			else                    a.x = r[y + 1];                       // If not left-column, reuse RIGHT sample from previous column
			
			if (x != -1 && y != 1) a.y = r[y + 2]; // If not left-column and not top-row, reuse RIGHT sample from previous column 1 row up
			else a.y = GetWaves(p[x + 1], offset.y + 0.2); // If left-column or top-row, reuse previously computed FBM coords
			
			if (y == -1) a.z = GetWaves(coord + offset + vec2(0.1, 0.0), p[x + 2]); // If bottom-row, generate the height & save FBM coords
			else a.z = GetWaves(p[x + 2], offset.y + 0.2); // If not bottom-row, reuse FBM coords
			
			r[y + 1] = a.z; // Save RIGHT height sample for later
			
			
			vec2 diff = a.x - a.yz;
			
			vec3 wavesNormal = vec3(diff, sqrt(1.0 - length2(diff))).yzx;
			
			vec3 refractVector = refract(-worldLightVector, wavesNormal, 1.0 / 1.3333);
			vec2 dist = refractVector.xz * (-verticalDist / refractVector.y) + (flatRefractVector.xz + offset);
			
			caustics += clamp01(length(dist) / distanceThreshold);
		}
	}
	
	caustics = 1.0 - caustics / 9.0;
	caustics *= 0.07 / pow2(distanceThreshold);
	
	return pow3(caustics);
}
#else
#define CalculateWaterCaustics(a, c, b) 1.0
#endif

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
	
	shading.caustics = CalculateWaterCaustics(position[1], shading.skylight, mask.water);
	
	shading.sunlight  = GetLambertianShading(normal, lightVector, mask) * shading.skylight;
	shading.sunlight  = ComputeSunlight(position[1], shading.sunlight);
	shading.sunlight *= 3.4 * SUN_LIGHT_LEVEL;
	
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