void SetupProjectionMatrix() {
	float gameTrueFOV = degrees(atan(1.0 / gbufferProjection[1].y) * 2.0);
	
	cfloat gameSetFOV = FOV_DEFAULT_TENS + FOV_DEFAULT_FIVES + FOV_DEFAULT_ONES;
	cfloat targetSetFOV = FOV_TRUE_TENS + FOV_TRUE_FIVES + FOV_TRUE_ONES;
	
	float targetTrueFOV = targetSetFOV + gameTrueFOV - gameSetFOV;
	
	projMatrix      = gbufferProjection;
	projMatrix[1].y = 1.0 / tan(radians(targetTrueFOV) * 0.5);
	projMatrix[0].x = projMatrix[1].y * gbufferProjection[0].x / gbufferProjection[1].y;
}
