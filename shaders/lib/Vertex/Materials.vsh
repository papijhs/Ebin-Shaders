float GetMaterialIDs(int mc_ID) { // Gather material masks
#if defined gbuffers_hand
	return 5.0;
#endif
	
	float materialID;
	
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
		case 8:
		case 9:
			materialID = 4.0; break; // Water
		default:
			materialID = 1.0;
	}
	
	// Custom Streams Mod ID's can go here:
//	if (mc_Entity.x == 8 || mc_Entity.x == 9 || mc_Entity.x == 235 || mc_Entity.x == 236 ... )
//		materialID = 4.0;
	
	return materialID;
}
