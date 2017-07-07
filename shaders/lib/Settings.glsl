const int noiseTextureResolution = 64; // [16 32 64 128 256 512 1024]
cfloat noiseRes = float(noiseTextureResolution);
cfloat noiseResInverse = 1.0 / noiseRes;
cfloat noiseScale = 64.0 / noiseRes;

const float zShrink = 4.0;


// GUI Settings
#define low_profile
//#define standard_profile


#if !defined low_profile
	#define GI_ENABLED
	#define AO_ENABLED
	//#define VOLUMETRIC_LIGHT
#endif

//#define FOG_ENABLED
#define FOG_POWER 3.0 // [1.0 2.0 3.0 4.0 6.0 8.0]

//#define WEATHER

//#define DEFAULT_TEXTURE_PACK

#ifdef DEFAULT_TEXTURE_PACK
	#define TEXTURE_PACK_RESOLUTION 16
#else
	#define TEXTURE_PACK_RESOLUTION_SETTING 128 // [16 32 64 128 256 512 1024 2048 4096]
	
	#define TEXTURE_PACK_RESOLUTION TEXTURE_PACK_RESOLUTION_SETTING
	
	#if !defined gbuffers_entities
		#define NORMAL_MAPS
	#endif
	
	#ifdef NORMAL_MAPS
		//#define TERRAIN_PARALLAX
	#endif
	
	//#define SPECULARITY_MAPS
#endif
