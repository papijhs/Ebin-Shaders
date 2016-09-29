uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

#ifdef FOV_OVERRIDE
	varying mat4 projection;
	varying mat4 projectionInverse;
	
	void SetupProjectionMatrices() {
		projection = gbufferProjection;
		projectionInverse = gbufferProjectionInverse;
		
		float gameTrueFOV = degrees(atan(1.0 / gbufferProjection[1].y) * 2.0);
		
		cfloat gameSetFOV = FOV_DEFAULT_TENS + FOV_DEFAULT_FIVES + FOV_DEFAULT_ONES;
		cfloat targetSetFOV = FOV_TRUE_TENS + FOV_TRUE_FIVES + FOV_TRUE_ONES;
		
		float targetTrueFOV = targetSetFOV + (gameTrueFOV - gameSetFOV) * targetSetFOV / gameSetFOV;
		
		projection      = gbufferProjection;
		projection[1].y = 1.0 / tan(radians(targetTrueFOV) * 0.5);
		projection[0].x = projection[1].y * gbufferProjection[0].x / gbufferProjection[1].y;
		
		projectionInverse = inverse(projection);
	}
	
	#define projMatrix projection
	#define projInverseMatrix projectionInverse
#else
	#define projMatrix gbufferProjection
	#define projInverseMatrix gbufferProjectionInverse
#endif
