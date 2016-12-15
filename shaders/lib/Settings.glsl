const int   shadowMapResolution      = 2048;  // [1024 2048 3072 4096 8192]
const float sunPathRotation          = -40.0; // [-60.0 -50.0 -40.0 -30.0 -20.0 -10.0 0.0 10.0 20.0 30.0 40.0 50.0 60.0]
const float shadowDistance           = 140.0;
const float shadowIntervalSize       = 4.0;
const bool  shadowHardwareFiltering0 = true;

const float wetnessHalflife          = 40.0;
const float drynessHalflife          = 40.0;

/*
** Transparent Gbuffers **
const int colortex0Format = RG32F;
const int colortex3Format = R11F_G11F_B10F;
const int colortex2Format = R8;

** Flat Gbuffers **
const int colortex1Format = R11F_G11F_B10F;
const int colortex4Format = RG32F;

** composite0 Buffer **
const int colortex5Format = RGB8;


const float eyeBrightnessHalflife = 1.5;
const float ambientOcclusionLevel = 0.65;
*/

const int noiseTextureResolution = 64;
cfloat noiseRes = noiseTextureResolution;
cfloat noiseResInverse = 1.0 / noiseRes;



// GUI Settings
#define low_profile
//#define standard_profile


//#define DEFAULT_TEXTURE_PACK


#define EXPOSURE            1.0  // [0.2 0.4 0.6 0.8 1.0 2.0 4.0]
#define SATURATION          1.1  // [0.0 0.5 1.0 1.1 1.2 1.3]
#define SUN_LIGHT_LEVEL     1.00 // [0.00 0.25 0.50 1.00 2.00 4.00]
#define SKY_LIGHT_LEVEL     1.00 // [0.00 0.25 0.50 1.00 2.00 4.00]
#define AMBIENT_LIGHT_LEVEL 1.00 // [0.00 0.25 0.50 1.00 2.00 4.00]
#define TORCH_LIGHT_LEVEL   1.00 // [0.00 0.25 0.50 1.00 2.00 4.00]
#define SKY_BRIGHTNESS      0.8  // [0.2 0.4 0.6 0.8 1.0 2.0 4.0]


#define SHADOW_MAP_BIAS 0.80     // [0.00 0.60 0.70 0.80 0.85 0.90]
#define SHADOW_TYPE 2 // [1 2]
#define PLAYER_SHADOW

#if !defined low_profile
	#define GI_ENABLED
#endif

//#define PLAYER_GI_BOUNCE
#define GI_RADIUS       16   // [4 8 16 32]
#define GI_SAMPLE_COUNT 40   // [20 40 80 128 160 256]
#define GI_BOOST
#define GI_TRANSLUCENCE 0.50  // [0.00 0.25 0.50 0.75 1.00]
#define GI_BRIGHTNESS   1.00 // [0.25 0.50 0.75 1.00 2.00 4.00]

#define BLOOM_ENABLED
#define BLOOM_AMOUNT        0.15 // [0.15 0.30 0.45]
#define BLOOM_CURVE         1.50 // [1.00 1.25 1.50 1.75 2.00]

//#define MOTION_BLUR
#define VARIABLE_MOTION_BLUR_SAMPLES
#define MAX_MOTION_BLUR_SAMPLE_COUNT            50    // [10 25 50 100]
#define VARIABLE_MOTION_BLUR_SAMPLE_COEFFICIENT 1.000 // [0.125 0.250 0.500 1.000]
#define CONSTANT_MOTION_BLUR_SAMPLE_COUNT       2     // [2 3 4 5 10]
#define MOTION_BLUR_INTENSITY                   1.0   // [0.5 1.0 2.0]
#define MAX_MOTION_BLUR_AMOUNT                  1.0   // [0.5 1.0 2.0]

#define WAVING_GRASS
#define WAVING_LEAVES
#define WAVING_WATER

#define COMPOSITE0_SCALE 0.50 // [0.25 0.33 0.40 0.50 0.75 1.00]
#define COMPOSITE0_NOISE

//#define FOG_ENABLED
#define FOG_POWER 3.0                      // [1.0 2.0 3.0 4.0 6.0 8.0]
#define AERIAL_PERSPECTIVE_AMOUNT 1.00 // [0.00 0.25 0.50 0.75 1.00 2.00 4.00]

#define CLOUDS_2D
#define CLOUD_HEIGHT_2D   512  // [384 512 640 768]
#define CLOUD_COVERAGE_2D 0.5  // [0.3 0.4 0.5 0.6 0.7]
#define CLOUD_SPEED_2D    1.00 // [0.25 0.50 1.00 2.00 4.00]

#define WAVE_MULT  1.0 // [0.0 0.5 1.0 1.5]
#define WAVE_SPEED 1.0 // [0.0 0.5 1.0 2.0]

//#define DEFORM
#define DEFORMATION 1 // [1 2 3]


//#define CUSTOM_HORIZON_HEIGHT
#define HORIZON_HEIGHT 62 // [5 62 72 80 128 192 208]
#define REFLECTION_EDGE_FALLOFF
//#define HIDE_ENTITIES
//#define CLEAR_WATER
#define NIGHTVISION
//#define WEATHER

//#define TIME_OVERRIDE
#define TIME_OVERRIDE_MODE 1 // [1 2 3]
#define CONSTANT_TIME_HOUR 3 // [0 3 6 9 12 15 18 21]
#define CUSTOM_DAY_NIGHT   1 // [1 2]
#define CUSTOM_TIME_MISC   1 // [1 2]


#define DEBUG_VIEW 1 // [-1 0 1 2 3 7]


//#define PHYSICAL_ATMOSPHERE
//#define FREEZE_TIME

//#define WATER_SHADOW


#ifdef DEFAULT_TEXTURE_PACK
	#define TEXTURE_PACK_RESOLUTION 16
#else
	#define TEXTURE_PACK_RESOLUTION_SETTING 128 // [16 32 64 128 256 512]
	
	#define TEXTURE_PACK_RESOLUTION TEXTURE_PACK_RESOLUTION_SETTING
	
	#define NORMAL_MAPS
	
	#ifdef NORMAL_MAPS
		//#define TERRAIN_PARALLAX
	#endif
	
	//#define SPECULARITY_MAPS
#endif

//#define FOV_OVERRIDE

#define FOV_DEFAULT_TENS  110 // [90 100 110 120 130 140 150]

#define FOV_TRUE_TENS  90 // [70 80 90 100 110]
#define FOV_TRUE_FIVES 0  // [0 5]
