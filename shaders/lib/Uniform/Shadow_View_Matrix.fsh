//#define TIME_OVERRIDE
//#define TELEFOCAL_SHADOWS

#if defined TIME_OVERRIDE || defined TELEFOCAL_SHADOWS
	flat varying mat4 shadowView;
	
	#define shadowViewMatrix shadowView
#else
	uniform mat4 shadowModelView;
	
	#define shadowViewMatrix shadowModelView
#endif
