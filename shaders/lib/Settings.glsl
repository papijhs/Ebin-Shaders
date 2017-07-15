//#define low_profile
#define standard_profile

#if !defined low_profile
	#define GI_ENABLED
	#define AO_ENABLED
	//#define VOLUMETRIC_LIGHT
#endif
