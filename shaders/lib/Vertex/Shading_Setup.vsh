void SetupShading() {
	float isNight;
	
	GetDaylightVariables(isNight, worldLightVector);
	
	lightVector = worldLightVector * mat3(gbufferModelViewInverse);
	sunVector   = worldLightVector * (1.0 - isNight * 2.0);
	
	float LdotUp = worldLightVector.y * (1.0 - isNight * 2.0);
	
	timeDay   = 1.0 - pow4(1.0 - clamp01( LdotUp - 0.02) / 0.98);
	timeNight = 1.0 - pow4(1.0 - clamp01(-LdotUp - 0.02) / 0.98);
	
	timeHorizon	= sqrt((1.0 - timeDay) * (1.0 - timeNight));
	
	
	vec3 sunlightDay      = vec3(1.00, 1.00, 1.00);
	vec3 sunlightNight    = vec3(0.23, 0.45, 1.00);
	vec3 sunlightSunrise  = vec3(1.00, 0.45, 0.10);
	
	vec3 skylightDay     = vec3(0.13, 0.26, 1.00);
	vec3 skylightNight   = vec3(0.25, 0.50, 1.00);
	vec3 skylightSunrise = vec3(0.29, 0.48, 1.00);
	vec3 skylightHorizon = skylightNight;
	
	
	sunlightDay     = setLength(sunlightDay    , 1.0);
	sunlightNight   = setLength(sunlightNight  , 0.005);
	sunlightSunrise = setLength(sunlightSunrise, 1.0);
	
	skylightDay     = setLength(skylightDay    , 1.00);
	skylightNight   = setLength(skylightNight  , 0.0005);
	skylightSunrise = setLength(skylightSunrise, 0.01);
	skylightHorizon = setLength(skylightHorizon, 0.003);
	
	
	sunlightColor =
		mix(sunlightDay, sunlightSunrise , timeHorizon) * timeDay +
		sunlightNight * timeNight;
	
	skylightColor =
		mix(skylightDay, skylightSunrise, timeHorizon) * timeDay +
		skylightNight * timeNight + skylightHorizon * timeHorizon;
}