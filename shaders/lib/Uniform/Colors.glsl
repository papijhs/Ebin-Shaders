float sunlightTemperatureDay = 5200.0;
float sunlightTemperatureSunrise = 2000.0;

float sunIlluminanceDay = 130000;
float sunIlluminanceSunrise = 130000;
float sunIlluminanceNight = 1.0;
float sunIlluminanceMoonrise = 1.0;

float skyIlluminanceDay = 27300.0;
float skyIlluminanceSunrise = 20000.0;
float skyIlluminanceNight = 0.2;
float skyIlluminanceMoonrise = 1;

vec3 sunlightDay      = vec3(RGBfromTemp(sunlightTemperatureDay));
vec3 sunlightNight    = vec3(0.23, 0.45, 1.00);
vec3 sunlightSunrise  = vec3(RGBfromTemp(sunlightTemperatureSunrise));
vec3 sunlightMoonrise = vec3(0.90, 1.00, 1.00);

vec3 skylightDay     = vec3(0.13, 0.26, 1.00);
vec3 skylightNight   = vec3(0.25, 0.50, 1.00);
vec3 skylightSunrise = vec3(0.29, 0.48, 1.00);
vec3 skylightHorizon = skylightNight;


//sunlightDay      *= 1.0 / length(sunlightDay      * lumaCoeff);
sunlightNight    *= 0.1 / length(sunlightNight    * lumaCoeff);
//sunlightSunrise  *= 2.0 / length(sunlightSunrise  * lumaCoeff);
sunlightMoonrise *= 0.5 / length(sunlightMoonrise * lumaCoeff);

skylightDay     *= 1.0  / length(skylightDay);
skylightNight   *= 0.03 / length(skylightNight);
skylightSunrise *= 0.01 / length(skylightSunrise);
skylightHorizon *= 0.03 / length(skylightHorizon);
