vec3 AerialPerspective(float dist, float skyLightmap) {
	float factor  = pow(dist, 1.4) * 0.000014 * (1.0 - isEyeInWater) * AERIAL_PERSPECTIVE_AMOUNT;
	      factor *= mix(skyLightmap * 0.7 + 0.3, 1.0, eyeBrightnessSmooth.g / 240.0);
	
	return pow(skylightColor, vec3(1.3 - clamp01(factor) * 0.4)) * factor;
}
