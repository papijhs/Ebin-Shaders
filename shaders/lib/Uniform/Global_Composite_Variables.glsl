#if defined fsh
	#ifdef CUSTOM_TIME_CYCLE
		varying mat4 shadowView;
		
		#define shadowViewMatrix shadowView
	#else
		uniform mat4 shadowModelView;
		
		#define shadowViewMatrix shadowModelView
	#endif
#endif

varying vec3 lightVector;

varying float timeDay;
varying float timeNight;
varying float timeHorizon;

varying vec3 sunlightColor;
varying vec3 skylightColor;
