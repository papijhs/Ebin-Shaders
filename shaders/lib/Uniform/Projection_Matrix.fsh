#ifdef FOV_OVERRIDE
	varying mat4 projection;
	
	#define projMatrix projection
#else
	uniform mat4 gbufferProjection;
	
	#define projMatrix gbufferProjection
#endif
