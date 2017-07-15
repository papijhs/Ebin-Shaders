float CalculateSunglow(float lightCoeff) {
	float sunglow = clamp01(lightCoeff - 0.01);
	      sunglow = pow8(sunglow);
	
	return sunglow;
}

//#define CUSTOM_HORIZON_HEIGHT
#define HORIZON_HEIGHT 62 // [5 62 72 80 128 192 208]

vec3 CalculateSkyGradient(vec3 worldSpacePosition, float sunglow, vec3 sunspot) {
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
	     color += sunspot * sunlightColor * sunlightColor * vec3(1.0, 0.8, 0.6);

	return color;
}

vec3 CalculateSunspot(float lightCoeff) {
	float sunspot  = clamp01(lightCoeff - 0.01);
	      sunspot  = pow(sunspot, 375.0);
	      sunspot  = pow(sunspot + 1.0, 400.0) - 1.0;
	      sunspot  = min(sunspot, 20.0) * 6.0;
	      sunspot  = sin(max(lightCoeff - 0.9985, 0.0) / 0.0015 * PI * 0.5) * 200.0;
	
	return vec3(sunspot);// * pow2(sunlightColor) * vec3(1.0, 0.8, 0.6);
}

vec3 CalculateMoonspot(float lightCoeff) {
	float moonspot  = clamp01(lightCoeff - 0.01);
	      moonspot  = pow(moonspot, 400.0);
	      moonspot  = pow(moonspot + 1.0, 400.0) - 1.0;
	      moonspot  = min(moonspot, 20.0) * 6.0;
	      moonspot *= timeNight * 200.0;
	
	return moonspot * pow2(sunlightColor);
}

#include "/lib/Fragment/Clouds.fsh"
#include "/lib/Fragment/Atmosphere.fsh"

#define STARS ON // [ON OFF]
#define REFLECT_STARS OFF // [ON OFF]
#define ROTATE_STARS OFF // [ON OFF]
#define STAR_SCALE 1.0 // [0.5 1.0 2.0 4.0]
#define STAR_BRIGHTNESS 1.00 // [0.25 0.50 1.00 2.00 4.00]
#define STAR_COVERAGE 1.000 // [0.950 0.975 1.000 1.025 1.050]

void CalculateStars(io vec3 color, vec3 worldDir, float visibility, cbool reflection) {
	if (!STARS) return;
	if (!REFLECT_STARS && reflection) return;
	
	float alpha = STAR_BRIGHTNESS * 2000.0 * pow2(clamp01(worldDir.y)) * timeNight * pow(visibility, 50.0);
	if (alpha <= 0.0) return;
	
	vec2 coord;
	
	if (ROTATE_STARS) {
		vec3 shadowCoord     = mat3(shadowViewMatrix) * worldDir;
		     shadowCoord.xz *= sign(sunVector.y);
		
		coord  = vec2(atan(shadowCoord.x, shadowCoord.z), acos(shadowCoord.y));
		coord *= 3.0 * STAR_SCALE * noiseScale;
	} else
		coord = worldDir.xz * (2.5 * STAR_SCALE * (2.0 - worldDir.y) * noiseScale);
	
	float noise  = texture2D(noisetex, coord * 0.5).r;
	      noise += texture2D(noisetex, coord).r * 0.5;
	
	float star = clamp01(noise - 1.3 / STAR_COVERAGE);
	
	color += star * alpha;
}

#define SKY_BRIGHTNESS 1.0 // [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.1 2.2 2.3 2.4 2.5 2.6 2.7 2.8 2.9 3.0 3.1 3.2 3.3 3.4 3.5 3.6 3.7 3.8 3.9 4.0]

vec3 CalculateSky(vec3 worldSpacePosition, vec3 rayPosition, float skyMask, float alpha, cbool reflection, float sunlight) {
	float visibility = (reflection ? alpha : CalculateFogFactor(worldSpacePosition, skyMask));
	if (!reflection && visibility < 0.000001) return vec3(0.0);
	
	vec3 worldSpaceVector = normalize(worldSpacePosition);
	
	float lightCoeff = dot(worldSpaceVector, worldLightVector) * sign(sunVector.y);
	
	float sunglow = CalculateSunglow(lightCoeff);
	vec3  sunspot = CalculateSunspot(lightCoeff) * (reflection ? sunlight : pow(visibility, 25) * alpha);
	vec3  moonspot = CalculateMoonspot(-lightCoeff) * (reflection ? sunlight : pow(visibility, 25) * alpha);
	
	
#ifdef PHYSICAL_ATMOSPHERE
	vec3 gradient  = ComputeAtmosphericSky(worldSpaceVector, visibility, sunspot) * 5.0;
	     gradient += CalculateSkyGradient(worldSpacePosition, sunglow, sunspot) * timeNight;
#else
	vec3 gradient = CalculateSkyGradient(worldSpacePosition, sunglow, sunspot);
#endif
	
	vec3 sky = gradient + moonspot;
	
	float cloudAlpha;
	Compute2DCloudPlane(sky, cloudAlpha, worldSpaceVector, rayPosition, sunglow, visibility);
	
	CalculateStars(sky, worldSpaceVector, visibility * (1.0 - cloudAlpha), reflection);
	
	return sky * SKY_BRIGHTNESS * 0.07;
}
