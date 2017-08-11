#version 410 compatibility
#define gbuffers_terrain
#define vsh
#define ShaderStage -2
#include "/lib/Syntax.glsl"
#include "/lib/Misc/Menu_Initializer.glsl"

float GetMaterialIDs(int mc_ID) { // Gather material masks
	float materialID = 1.0;
	
	switch(mc_ID) {
		case 31:                     // Tall Grass
		case 37:                     // Dandelion
		case 38:                     // Rose
		case 59:                     // Wheat
		case 83:                     // Sugar Cane
		case 141:                    // Carrot
		case 142:                    // Potatoes
		case 175:                    // Double Tall Grass
		case 18:                     // Generic leaves
		case 106:                    // Vines
		case 161:                    // New leaves
			materialID = 2.0; break; // Translucent
		case 10:                     // Flowing Lava
		case 11:                     // Still Lava
		case 50:                     // Torch
		case 51:                     // Fire
		case 89:                     // Glowstone
		case 124:                    // Redstone Lamp
			materialID = 3.0; break; // Emissive
	}
	
	return materialID;
}


#include "gbuffers_main.vsh"
