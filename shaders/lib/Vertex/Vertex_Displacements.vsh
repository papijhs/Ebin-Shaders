vec3 CalculateVertexDisplacements(vec3 worldSpacePosition, float skyLightmap) {
	worldSpacePosition += cameraPosition.xyz;
	
	vec3 wave = vec3(0.0);
	
#if defined gbuffers_terrain || defined gbuffers_shadow
	float grassWeight = float(fract(texcoord.t * 64.0) < 0.01);
	
	switch(int(mc_Entity.x)) {
		case 31:
		case 37:
		case 38:
		case 59:  wave += GetWavingGrass(worldSpacePosition, skyLightmap * grassWeight); break;
		case 18:
		case 161: wave += GetWavingLeaves(worldSpacePosition, skyLightmap); break;
		case 8:
		case 9:
		case 111: wave += GetWavingWater(worldSpacePosition, 1.0); break;
	}
#endif
	
	return wave;
}
