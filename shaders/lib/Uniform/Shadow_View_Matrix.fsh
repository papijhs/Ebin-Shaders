#ifdef TIME_OVERRIDE
	varying mat4 shadowView;
	
	#define shadowViewMatrix shadowView
#else
	uniform mat4 shadowModelView;
	
	#define shadowViewMatrix shadowModelView
#endif
