vec3 CalculateVertexDisplacements(vec3 worldSpacePosition) {
	vec3 worldPosition = worldSpacePosition + cameraPos;
	
#if !defined gbuffers_shadow && !defined gbuffers_basic
	worldPosition += previousCameraPosition - cameraPosition;
#endif
	
	vec3 displacement = vec3(0.0);
	
#if defined gbuffers_terrain || defined gbuffers_water || defined gbuffers_shadow
	switch(int(mc_Entity.x)) {
		case 31:
		case 37:
		case 38:
		case 59:
		case 142: displacement += GetWavingGrass(worldPosition, false); break;
		case 175: displacement += GetWavingGrass(worldPosition,  true); break;
		case 18:
		case 161: displacement += GetWavingLeaves(worldPosition); break;
		case 8:
		case 9:
		case 111: displacement += GetWavingWater(worldPosition); break;
	}
#endif
	
#if !defined gbuffers_hand
	displacement += TerrainDeformation(worldSpacePosition) - worldSpacePosition;
#endif
	
	return displacement;
}
