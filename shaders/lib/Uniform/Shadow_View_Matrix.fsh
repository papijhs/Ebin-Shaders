#if defined fsh
	#ifdef CUSTOM_TIME_CYCLE
		varying mat4 shadowView;
		
		#define shadowViewMatrix shadowView
	#else
		uniform mat4 shadowModelView;
		
		#define shadowViewMatrix shadowModelView
	#endif
#endif
