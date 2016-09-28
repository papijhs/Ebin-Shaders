uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

#ifdef FOV_OVERRIDE
	varying mat4 projection;
	varying mat4 projectionInverse;
	
	void SetupProjectionMatrices() {
		projection = gbufferProjection;
		projectionInverse = gbufferProjectionInverse;
	}
	
	#define projMatrix projection
	#define projInverseMatrix projectionInverse
#else
	#define projMatrix gbufferProjection
	#define projInverseMatrix gbufferProjectionInverse
#endif
