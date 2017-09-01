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

vec3 CalculateSunspot(float lightCoeff) {
	return vec3(clamp01(sin(clamp01(lightCoeff - 0.9985) / 0.0015 * PI * 0.5)) * 200.0);
}

vec3 CalculateMoonspot(float lightCoeff) {
	float moonspot  = clamp01(lightCoeff - 0.01);
	      moonspot  = pow(moonspot, 400.0);
	      moonspot  = pow(moonspot + 1.0, 400.0) - 1.0;
	      moonspot  = min(moonspot, 20.0) * 6.0;
	      moonspot *= timeNight * 200.0;
	
	return moonspot * pow2(sunlightColor);
}

vec3 skyColor = vec3(0.1, 0.3, 0.9) * 0.2;
vec3 skyAbsorb = vec3(0.8, 0.5, 0.2);
#define absorb(a) powf(skyAbsorb, a)

#define phaseMie(a) (.0348151 / pow(1.5625 - 1.5*a,1.5))

float phaseRayleigh(float x) {
	return 0.4 * x + 1.12;
}

vec3 calculateSky(vec3 color, float SdotF, float MdotF, float DdotF) {
	float sunFade  = smoothstep(0.0, 0.3, clamp01( sunVector.y));
	float moonFade = smoothstep(0.0, 0.3, clamp01(-sunVector.y));
	//float sunFade  = smoothstep(0.0, 0.3, mDot(sunVec, upVec));
	//float moonFade = smoothstep(0.0, 0.3, mDot(moonVec, upVec));


	float zenithAngleS = sin(-sunVector.y * (PI * 0.5)) + 1.0;
	float zenithAngleM = sin( sunVector.y * (PI * 0.5)) + 1.0;
	//float zenithAngleS = sin(-dot(sunVec,  upVec) * (PI * 0.5)) + 1.0;
	//float zenithAngleM = sin(-dot(moonVec, upVec) * (PI * 0.5)) + 1.0;

	vec3 sunColor   = absorb(zenithAngleS * 1.5);
	vec3 moonColor  = absorb(zenithAngleM * 1.5) * vec3(0.08,0.13,0.18) * 0.3;
	vec3 lightColor = sunColor * sunFade + moonColor * moonFade;
	//vec3 ambientColor = vec3(2.7, 1.0, 0.7) * (skyColor * lightColor * 6.0);
	
//	float rainy = mix(wetness, 1.0, rainStrength);
	
	float thickness = sin(DdotF * (PI * 0.5)) + 1.0;
	float fogThickness = pow(min(1.0 + DdotF, 1.0), 5.0);
	float mieStrength = pow(zenithAngleS, 0.4) * 0.1 * (1.0 + fogThickness * 7.0);
	float mieDistribution = 1.0;
//	float mieDistribution = mix(1.0, 0.01, rainy);
	
	vec3 absorption = absorb(pow(thickness, 10.0));
	vec3 fogAbsorption = absorb(pow(fogThickness, 10.0));
	
	vec3 mieS = pow(phaseMie(SdotF), mieDistribution) * mieStrength * absorption;
	vec3 mieM = pow(phaseMie(MdotF), mieDistribution) * mieStrength * absorption;
	
	vec3 rayleighS = phaseRayleigh(SdotF) * skyColor * absorption;
	vec3 rayleighM = phaseRayleigh(MdotF) * skyColor * absorption;
	
	vec3 skyColorS = (mieS + rayleighS) * sunColor;
	vec3 skyColorM = (mieM + rayleighM) * moonColor;
	
	vec3 groundFog = fogThickness * lightColor * vec3(0.1, 0.12, 0.13);
	
	color *= powf(absorption, 6.0);
	color *= powf(fogAbsorption, 6.0);
	
	vec3 sky = color + max0(skyColorS + skyColorM + groundFog) * mix(1.5, 0.02, moonFade) / 0.07;
	
	return sky;
}

#include "/lib/Fragment/Atmosphere.fsh"

#define SKY_BRIGHTNESS 1.0 // [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.1 2.2 2.3 2.4 2.5 2.6 2.7 2.8 2.9 3.0 3.1 3.2 3.3 3.4 3.5 3.6 3.7 3.8 3.9 4.0]

vec3 CalculateSky(vec3 worldSpacePosition) {
	vec3 worldSpaceVector = normalize(worldSpacePosition);
	
	float lightCoeff = dot(worldSpaceVector, worldLightVector) * sign(sunVector.y);
	
	vec3  sunspot = CalculateSunspot(lightCoeff);
	
	float SdotF = dot(sunVector, worldSpaceVector);
	float MdotF = -SdotF;
	float DdotF = -worldSpaceVector.y;
	
	vec3 sky = calculateSky(sunspot, SdotF, MdotF, DdotF);
	
	return sky * SKY_BRIGHTNESS * 0.07;
}

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
	
	sunlightColor = CalculateSky(worldLightVector) / 200.0 * 7.0;
	skylightColor = CalculateSky(vec3(0.0, 1.0, 0.0));
	skylightColor += CalculateSky(vec3(1.0, 1.0, 0.0));
	skylightColor += CalculateSky(vec3(0.0, 1.0, 1.0));
	skylightColor += CalculateSky(vec3(0.0, 1.0, -1.0));
	skylightColor += CalculateSky(vec3(1.0, 1.0, 0.0));
	skylightColor *= 0.5;
}