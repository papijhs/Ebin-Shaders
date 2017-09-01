float CalculateSunglow(float lightCoeff) {
	float sunglow = clamp01(lightCoeff - 0.01);
	      sunglow = pow8(sunglow);
	
	return sunglow;
}

//#define CUSTOM_HORIZON_HEIGHT
#define HORIZON_HEIGHT 62 // [5 62 72 80 128 192 208]

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

float CalculateSunspot(float lightCoeff) {
	return sin(max(lightCoeff - 0.9985, 0.0) / 0.0015 * PI * 0.5);
}

float MiePhase(float x) {
	return (0.0348151 / pow(1.5625 - 1.5 * x, 1.5));
}

float RayleighPhase(float x) {
	return 0.4 * x + 1.12;
}

vec3 Absorb(float x) {
	return powf(vec3(0.8, 0.5, 0.2), x);
}

vec3 CalculateSkyGradient(vec3 color, float SdotF, float MdotF, float DdotF) {
	vec3 skyColor = vec3(0.1, 0.3, 0.9) * 0.2;
	
	float sunFade  = smoothstep(0.0, 0.3, clamp01( sunVector.y));
	float moonFade = smoothstep(0.0, 0.3, clamp01(-sunVector.y));
	
	float zenithAngleS = sin(-sunVector.y * (PI * 0.5)) + 1.0;
	float zenithAngleM = sin( sunVector.y * (PI * 0.5)) + 1.0;
	
	vec3 sunColor   = Absorb(zenithAngleS * 1.5);
	vec3 moonColor  = Absorb(zenithAngleM * 1.5) * vec3(0.08,0.13,0.18) * 0.3;
	vec3 lightColor = sunColor * sunFade + moonColor * moonFade;
	
//	float rainy = mix(wetness, 1.0, rainStrength);
	
	float thickness = sin(DdotF * (PI * 0.5)) + 1.0;
	float fogThickness = pow(min(1.0 + DdotF, 1.0), 5.0);
	float mieStrength = pow(zenithAngleS, 0.4) * 0.1 * (1.0 + fogThickness * 7.0);
	float mieDistribution = 1.0;
//	float mieDistribution = mix(1.0, 0.01, rainy);
	
	vec3 absorption = Absorb(pow(thickness, 10.0));
	vec3 fogAbsorption = Absorb(pow(fogThickness, 10.0));
	
	vec3 mieS = pow(MiePhase(SdotF), mieDistribution) * mieStrength * absorption;
	vec3 mieM = pow(MiePhase(MdotF), mieDistribution) * mieStrength * absorption;
	
	vec3 rayleighS = RayleighPhase(SdotF) * skyColor * absorption;
	vec3 rayleighM = RayleighPhase(MdotF) * skyColor * absorption;
	
	vec3 skyColorS = (mieS + rayleighS) * sunColor;
	vec3 skyColorM = (mieM + rayleighM) * moonColor;
	
	vec3 groundFog = fogThickness * lightColor * vec3(0.1, 0.12, 0.13);
	
	color *= powf(absorption, 6.0);
	color *= powf(fogAbsorption, 6.0);
	
	return color + max0(skyColorS + skyColorM + groundFog) * mix(1.5, 0.02, moonFade) / 0.07;
}

#include "/lib/Fragment/Compute2DClouds.fsh"
#include "/lib/Fragment/Compute3DClouds.fsh"
#include "/lib/Fragment/Atmosphere.fsh"

#define STARS ON // [ON OFF]
#define REFLECT_STARS OFF // [ON OFF]
#define ROTATE_STARS OFF // [ON OFF]
#define STAR_SCALE 1.0 // [0.5 1.0 2.0 4.0]
#define STAR_BRIGHTNESS 1.00 // [0.25 0.50 1.00 2.00 4.00]
#define STAR_COVERAGE 1.000 // [0.950 0.975 1.000 1.025 1.050]

vec4 CalculateStars(vec3 worldDir, cbool reflection) {
	if (!STARS) return vec4(0.0);
	if (reflection && !REFLECT_STARS) return vec4(0.0);
	
	float alpha = STAR_BRIGHTNESS * 2000.0 * pow2(clamp01(worldDir.y)) * timeNight;
	if (alpha <= 0.0) return vec4(0.0);
	
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
	
	return vec4(vec3(star), alpha);
}

#define SKY_BRIGHTNESS 1.0 // [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.1 2.2 2.3 2.4 2.5 2.6 2.7 2.8 2.9 3.0 3.1 3.2 3.3 3.4 3.5 3.6 3.7 3.8 3.9 4.0]

vec3 CalculateSky(vec3 worldSpacePosition, vec3 rayPosition, float skyMask, float alpha, cbool reflection, float sunlight) {
	float visibility = (reflection ? alpha : CalculateFogFactor(worldSpacePosition, skyMask));
	if (!reflection && visibility < 0.000001) return vec3(0.0);
	
	vec3 worldSpaceVector = normalize(worldSpacePosition);
	
	float lightCoeff = dot(worldSpaceVector, worldLightVector) * sign(sunVector.y);
	
	float sunglow  = CalculateSunglow(lightCoeff);
//	vec3  sunspot  = CalculateSunspot(lightCoeff) * (reflection ? sunlight : pow(visibility, 25) * alpha);
//	vec3  moonspot = CalculateMoonspot(-lightCoeff) * (reflection ? sunlight : pow(visibility, 25) * alpha);
	
#ifdef PHYSICAL_ATMOSPHERE
//	vec3 gradient  = ComputeAtmosphericSky(worldSpaceVector, visibility, sun) * 5.0;
//	     gradient += CalculateSkyGradient(worldSpacePosition, sunglow) * timeNight;
#else
//	vec3 gradient = CalculateSkyGradient(worldSpacePosition, sunglow) + sun * pow2(sunlightColor) * vec3(1.0, 0.8, 0.6);
#endif
	
	
	vec3 planets = vec3(CalculateSunspot(lightCoeff) * 100.0 + CalculateSunspot(-lightCoeff));
	vec4 stars = CalculateStars(worldSpaceVector, reflection);
	
	float SdotF = dot(sunVector, worldSpaceVector);
	float MdotF = -SdotF;
	float DdotF = -worldSpaceVector.y;
	
	vec3 sky = mix(planets, stars.rgb, stars.a * float(length(planets) <= 0.0));
	     sky = CalculateSkyGradient(sky, SdotF, MdotF, DdotF);
	
	vec4 cloud2D = Compute2DClouds(worldSpaceVector, rayPosition, sunglow);
	vec4 cloud3D = Compute3DClouds(worldSpacePosition, rayPosition, reflection);
	
	sky = mix(sky, cloud2D.rgb, cloud2D.a);
	sky = mix(sky, cloud3D.rgb, cloud3D.a);
	
	return sky * SKY_BRIGHTNESS * 0.07;
}
