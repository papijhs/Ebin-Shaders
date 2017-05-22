float CalculateSunglow(vec3 worldSpaceVector) {
	float sunglow = clamp01(dot(worldSpaceVector, worldLightVector) - 0.01);
	      sunglow = pow8(sunglow);
	
	return sunglow;
}

vec3 CalculateSkyGradient(vec3 worldSpacePosition, float sunglow) {
#ifdef CUSTOM_HORIZON_HEIGHT
	float radius = max(176.0, far * sqrt(2.0));
	
	worldSpacePosition   *= radius / length(worldSpacePosition.xz); // Reproject the world vector to have a consistent horizon height
	worldSpacePosition.y += cameraPosition.y - HORIZON_HEIGHT;
#endif
	
	float gradientCoeff = pow4(1.0 - abs(normalize(worldSpacePosition).y) * 0.5);
	
	vec3 primaryHorizonColor  = SetSaturationLevel(skylightColor, mix(1.25, 0.6, gradientCoeff * timeDay));
	     primaryHorizonColor *= gradientCoeff * 0.5 + 1.0;
	     primaryHorizonColor  = mix(primaryHorizonColor, sunlightColor, gradientCoeff * sunglow * timeDay);
	
	vec3 sunglowColor = mix(skylightColor, sunlightColor * 0.5, gradientCoeff * sunglow) * sunglow;
	
	vec3 color  = primaryHorizonColor * gradientCoeff * 8.0;
	     color *= sunglowColor * 2.0 + 1.0;
	     color += sunglowColor * 5.0;
	
	return color;
}

vec3 CalculateSunspot(vec3 worldSpaceVector) {
	float sunspot  = clamp01(dot(worldSpaceVector, worldLightVector) - 0.01);
	      sunspot  = pow(sunspot, 375.0);
	      sunspot  = pow(sunspot + 1.0, 400.0) - 1.0;
	      sunspot  = min(sunspot, 20.0) * 6.0;
	      sunspot *= 1.0 + timeNight * 5.0;
	
	return sunspot * sunlightColor * sunlightColor * vec3(1.0, 0.8, 0.6);
}

#include "/lib/Fragment/Clouds.fsh"
#include "/lib/Fragment/Atmosphere.fsh"

vec3 CalculateStars(vec3 color, vec3 worldDir) {
	if (worldDir.y <= 0.0) return color;
	
	vec2 coord = worldDir.xz * (2.5 * (2.0 - worldDir.y) * noiseScale);
	
//	vec3 shadowCoord = mat3(shadowViewMatrix) * worldDir;
	
//	shadowCoord.xz *= sign(sunVector.y);
	
//	coord.x = atan(shadowCoord.x, shadowCoord.z);
//	coord.y = acos(shadowCoord.y);
	
//	coord *= 5.0 * noiseScale;
	
	float noise  = texture2D(noisetex, coord * 0.5).r;
	      noise += texture2D(noisetex, coord).r * 0.5;
	
	float star = clamp01(noise - 1.3);
	
	return color + star * 29000.0 * pow2(worldDir.y) * timeNight;
}

vec3 CalculateSky(vec3 worldSpacePosition, vec3 rayPosition, float skyMask, float alpha, cbool reflection, float sunlight) {
	float visibility = (reflection ? alpha : CalculateFogFactor(worldSpacePosition, FOG_POWER, skyMask));
	if (!reflection && visibility < 0.000001) return vec3(0.0);
	
	vec3 worldSpaceVector = normalize(worldSpacePosition);
	
	float sunglow = CalculateSunglow(worldSpaceVector);
	
#ifdef PHYSICAL_ATMOSPHERE
	vec3 gradient  = ComputeAtmosphericSky(worldSpaceVector, visibility) * 3.0;
	     gradient += CalculateSkyGradient(worldSpacePosition, sunglow) * timeNight;
#else
	vec3 gradient = CalculateSkyGradient(worldSpacePosition, sunglow);
#endif
	
	vec3 sunspot = CalculateSunspot(worldSpaceVector) * (reflection ? sunlight : pow(visibility, 25) * alpha);
	
	vec3 sky = gradient + sunspot;
	
//	sky = CalculateStars(sky, worldSpaceVector);
	
	Compute2DCloudPlane(sky, worldSpaceVector, rayPosition, sunglow, visibility);
	
	return sky * SKY_BRIGHTNESS;
}
