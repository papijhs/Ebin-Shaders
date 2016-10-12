float GetLambertianShading(vec3 normal) {
	return clamp01(dot(normal, lightVector));
}

float GetLambertianShading(vec3 normal, Mask mask) {
	float shading = clamp01(dot(normal, lightVector));
	      shading = mix(shading, 1.0, mask.grass);
	      shading = mix(shading, 0.5, mask.leaves);
	
	return shading;
}

#define GetDiffuseShading(a, b, c, d) GetLambertianShading(b, d)
