vec3 CalculateVertexDisplacements(vec3 worldSpacePosition, float skyLightmap) {
	vec3 worldPosition = worldSpacePosition + cameraPosition();
	
	vec3 wave = vec3(0.0);
	
#if defined gbuffers_terrain || defined gbuffers_water || defined gbuffers_shadow
	float grassWeight = float(fract(texcoord.t * 64.0) < 0.01);
	
	switch(int(mc_Entity.x)) {
		case 31:
		case 37:
		case 38:
		case 59:  wave += GetWavingGrass(worldPosition, skyLightmap * grassWeight); break;
		case 18:
		case 161: wave += GetWavingLeaves(worldPosition, skyLightmap); break;
		case 8:
		case 9:
		case 111: wave += GetWavingWater(worldPosition, 1.0); break;
	}
#endif
	
	wave += TerrainDeformation(worldSpacePosition) - worldSpacePosition;
	
	return wave;
}
