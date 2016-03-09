const int   shadowMapResolution      = 4096;    //[1024 2048 3072 4096]
const float sunPathRotation          = 40.0;
const float shadowDistance           = 140.0;
const float shadowIntervalSize       = 4.0;
const bool  shadowHardwareFiltering0 = true;

const int RGB8            = 0;
const int RG16            = 0;
const int RGB16           = 0;
const int colortex0Format = RGB16;
const int colortex2Format = RGB16;
const int colortex3Format = RGB8;

varying vec3 lightVector;

varying float timeDay;
varying float timeNight;
varying float timeHorizon;

varying vec3 colorSunlight;
varying vec3 colorSkylight;
varying vec3 colorHorizon;