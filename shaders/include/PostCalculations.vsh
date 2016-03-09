	vec3 sunVector = normalize(sunPosition);    //Engine-time overrides will happen by modifying sunVector
	
	lightVector = sunVector * mix(1.0, -1.0, float(dot(sunVector, upPosition) < 0.0));
	
	
	float sunUp   = dot(sunVector, normalize(upPosition));
	
	timeDay     = sqrt(sqrt(clamp01( sunUp)));
	timeNight   = sqrt(sqrt(clamp01(-sunUp)));
	timeHorizon = (1.0 - timeDay) * (1.0 - timeNight);
	
	
	const vec3 sunlightDay =
	vec3(1.0, 1.0, 1.0);
	
	const vec3 sunlightNight =
	vec3(1.0, 1.0, 1.0);
	
	const vec3 sunlightHorizon =
	vec3(1.0, 1.0, 1.0);
	
	colorSunlight = sunlightDay * timeDay + sunlightNight * timeNight + sunlightHorizon * timeHorizon;
	
	
	const vec3 skylightDay =
	vec3(1.0, 1.0, 1.0);
	
	const vec3 skylightNight =
	vec3(1.0, 1.0, 1.0);
	
	const vec3 skylightHorizon =
	vec3(1.0, 1.0, 1.0);
	
	colorSkylight = skylightDay * timeDay + skylightNight * timeNight + skylightHorizon * timeHorizon;
	
	
	const vec3 horizoncolorDay =
	vec3(1.0, 1.0, 1.0);
	
	const vec3 horizoncolorNight =
	vec3(1.0, 1.0, 1.0);
	
	const vec3 horizoncolorHorizon =
	vec3(1.0, 1.0, 1.0);
	
	colorHorizon = horizoncolorDay * timeDay + horizoncolorNight * timeNight + horizoncolorHorizon * timeHorizon;