#define time frameTimeCounter
#define dayCycle sunAngle

#ifdef gbuffers_shadow
	#define position cameraPosition
#else
	#define position previousCameraPosition
#endif
