// {
	float isNight;
	
	GetDaylightVariables(isNight, worldLightVector);
	
	lightVector = mat3(gbufferModelView) * worldLightVector;
	sunVector   = worldLightVector * (1.0 - isNight * 2.0);
	
	float LdotUp = worldLightVector.y * (1.0 - isNight * 2.0);
	
	cfloat timePower = 4.0;
	
	timeDay   = 1.0 - pow(1.0 - clamp01( LdotUp - 0.1) / 0.9, timePower);
	timeNight = 1.0 - pow(1.0 - clamp01(-LdotUp), timePower);
	
	timeHorizon	= (1.0 - timeDay) * (1.0 - timeNight);
	
	
	float timeSunrise  = timeHorizon * timeDay;
	float timeMoonrise = timeHorizon * timeNight;
	
	
	#include "/lib/Uniform/Colors.glsl"
	
	
	sunlightColor =
		mix(sunlightDay  , sunlightSunrise , timeHorizon) * timeDay +
		mix(sunlightNight, sunlightMoonrise, timeMoonrise * timeNight) * timeNight;
	
	skylightColor =
		mix(skylightDay, skylightSunrise, timeHorizon) * timeDay +
		skylightNight * timeNight + skylightHorizon * timeHorizon;
// }
