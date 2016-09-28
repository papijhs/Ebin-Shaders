uniform mat4 gbufferProjection;

#ifdef FOV_OVERRIDE
	varying mat4 projection;
	
	void SetupProjectionMatrix() {
		projection = gbufferProjection;
	}
	
	#define projMatrix projection
#else
	#define projMatrix gbufferProjection
#endif
