void SetupShading() {
	float isNight;
	
	GetDaylightVariables(isNight, worldLightVector);
	
	lightVector = worldLightVector * mat3(gbufferModelViewInverse);
	sunVector   = worldLightVector * (1.0 - isNight * 2.0);
	
	float LdotUp = worldLightVector.y * (1.0 - isNight * 2.0);
	
	timeDay   = 1.0 - pow4(1.0 - clamp01( LdotUp - 0.02) / 0.98);
	timeNight = 1.0 - pow4(1.0 - clamp01(-LdotUp - 0.02) / 0.98);
	
	timeHorizon	= sqrt((1.0 - timeDay) * (1.0 - timeNight));
	
	
	
	vec3 sunlightDay      = vec3(1.00, 1.00, 1.00)*3.0;
	vec3 sunlightNight    = vec3(0.23, 0.45, 1.00)*3.0;
	vec3 sunlightSunrise  = vec3(1.00, 0.45, 0.10)*3.0;
	
	vec3 skylightDay     = vec3(0.13, 0.26, 1.00)*3.0;
	vec3 skylightNight   = vec3(0.25, 0.50, 1.00)*3.0;
	vec3 skylightSunrise = vec3(0.29, 0.48, 1.00)*3.0;
	vec3 skylightHorizon = skylightNight;
	
#ifdef PRECOMPUTED_ATMOSPHERE
	vec3 transmit = vec3(1.0);
	SkyAtmosphere(sunVector, transmit);
	sunlightDay = 1.0 * sunbright * transmit;

	transmit = vec3(1.0);
	skylightDay = SkyAtmosphere(normalize(vec3(0,1,0)), transmit) * skybright;
	
	sunlightColor = sunlightDay;
	
	skylightColor = mix(skylightDay, skylightSunrise, timeHorizon) * timeDay + skylightNight * timeNight + skylightHorizon * timeHorizon;
	skylightColor = skylightDay;
#else
	sunlightDay     = setLength(sunlightDay    , 4.0)*3.0;
	sunlightNight   = setLength(sunlightNight  , 0.1);
	sunlightSunrise = setLength(sunlightSunrise, 4.0);

	skylightDay     = setLength(skylightDay    , 0.40);
	skylightNight   = setLength(skylightNight  , 0.004);
	skylightSunrise = setLength(skylightSunrise, 0.01);
	skylightHorizon = setLength(skylightHorizon, 0.003);

	sunlightColor = mix(sunlightDay, sunlightSunrise, timeHorizon) * timeDay + sunlightNight * timeNight;
	skylightColor = mix(skylightDay, skylightSunrise, timeHorizon) * timeDay + skylightNight * timeNight + skylightHorizon * timeHorizon;
#endif
}
