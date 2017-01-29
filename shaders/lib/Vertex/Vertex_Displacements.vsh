vec3 CalculateVertexDisplacements(vec3 worldSpacePosition) {
	vec3 worldPosition = worldSpacePosition + cameraPos;
	
	vec3 wave = vec3(0.0);
	
#if !defined gbuffers_hand && !defined gbuffers_basic
	switch(int(mc_Entity.x)) {
		case 31:
		case 37:
		case 38:
		case 59:
		case 142: wave += GetWavingGrass(worldPosition, false); break;
		case 175: wave += GetWavingGrass(worldPosition,  true); break;
		case 18:
		case 161: wave += GetWavingLeaves(worldPosition); break;
		case 8:
		case 9:
		case 111: wave += GetWavingWater(worldPosition); break;
	}
#endif
	
#if !defined gbuffers_hand
	wave += TerrainDeformation(worldSpacePosition) - worldSpacePosition;
#endif
	
	return wave;
}
