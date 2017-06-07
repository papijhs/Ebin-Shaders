#define time frameTimeCounter
#define dayCycle sunAngle

#if defined gbuffers_shadow
	#define position cameraPosition
#else
	#define position previousCameraPosition
#endif
