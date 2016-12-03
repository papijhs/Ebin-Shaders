float CalculateSunglow(vec3 worldSpaceVector) {
	float sunglow = max0(dot(worldSpaceVector, worldLightVector) - 0.01);
	      sunglow = pow(sunglow, 8.0);
	
	return sunglow;
}

vec3 CalculateSkyGradient(vec3 worldSpacePosition, float sunglow) {
#ifdef CUSTOM_HORIZON_HEIGHT
	float radius = max(176.0, far * sqrt(2.0));
	
	worldSpacePosition   *= radius / length(worldSpacePosition.xz); // Reproject the world vector to have a consistent horizon height
	worldSpacePosition.y += cameraPosition.y - HORIZON_HEIGHT;
#endif
	
	float gradientCoeff = pow(1.0 - abs(normalize(worldSpacePosition).y) * 0.5, 4.0);
	
	vec3 primaryHorizonColor  = SetSaturationLevel(skylightColor, mix(1.25, 0.6, gradientCoeff * timeDay));
	     primaryHorizonColor *= (1.0 + gradientCoeff * 0.5);
	     primaryHorizonColor  = mix(primaryHorizonColor, sunlightColor, gradientCoeff * sunglow * timeDay);
	
	vec3 sunglowColor = mix(skylightColor, sunlightColor * 0.5, gradientCoeff * sunglow) * sunglow;
	
	vec3 color  = primaryHorizonColor * gradientCoeff * 8.0;
	     color *= 1.0 + sunglowColor * 2.0;
	     color += sunglowColor * 5.0;
	
	return color;
}

vec3 CalculateSunspot(vec3 worldSpaceVector) {
	float sunspot  = max0(dot(worldSpaceVector, worldLightVector) - 0.01);
	      sunspot  = pow(sunspot, 375.0);
	      sunspot  = pow(sunspot + 1.0, 400.0) - 1.0;
	      sunspot  = min(sunspot, 20.0) * 6.0;
	
	return sunspot * sunlightColor * sunlightColor * vec3(1.0, 0.8, 0.6);
}

#include "/lib/Fragment/Clouds.fsh"
#include "/lib/Fragment/Atmosphere.fsh"

vec3 CalculateAtmosphericSky(vec3 worldSpacePosition) {
	vec3 worldPosition = vec3(0.0, planetRadius + 1.061e3 + max0(cameraPosition.y - HORIZON_HEIGHT) * 400.0, 0.0);
	
	return ComputeAtmosphericSky(worldSpacePosition, worldPosition, sunVector, 2.0);
}

vec3 CalculateSky(vec3 worldSpacePosition, vec3 rayPosition, float skyMask, float alpha, cbool reflection, float sunlight) {
	float visibility = CalculateFogFactor(worldSpacePosition, FOG_POWER, skyMask);
	if (!reflection && visibility < 0.001) return vec3(0.0);
	
	vec3 worldSpaceVector = normalize(worldSpacePosition);
	
	float sunglow = CalculateSunglow(worldSpaceVector);
	
#ifdef PHYSICAL_ATMOSPHERE
	vec3 gradient = CalculateAtmosphericSky(worldSpacePosition);
	vec3 sunspot  = vec3(0.0);
#else
	vec3 gradient = CalculateSkyGradient(worldSpacePosition, sunglow) * skyIlluminance;
	vec3 sunspot  = CalculateSunspot(worldSpaceVector) * (reflection ? sunlight : pow(visibility, 25) * alpha);
#endif
	
	vec3 sky = gradient + sunspot;
	
	Compute2DCloudPlane(sky, worldSpaceVector, rayPosition, sunglow, visibility);
	
	return sky;
}
