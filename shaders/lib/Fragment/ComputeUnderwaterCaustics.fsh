//#define WATER_CAUSTICS
#include "/UserProgram/WaterHeight.glsl"
//#define VARIABLE_WATER_HEIGHT
#define UNDERWATER_LIGHT_DEPTH 16 // [4 8 16 32 64 65536]

#include "/lib/Fragment/Water_Waves.fsh"

float ComputeUnderwaterCaustics(vec3 worldPos, float skyLightmap, float waterMask) {
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