// [Drobot2014a] Low Level Optimisations for GNC
#define fsqrt(x) intBitsToFloat(0x1FBD1DF5 + (floatBitsToInt(x) >> 1)) // Error of 1.42% Literally Free

#define finversesqrt(x) intBitsToFloat(0x5F33E79F - (floatBitsToInt(x) >> 1)) // Error of 1.62%


float flength(vec2 x) {
	return fsqrt(dot(x, x));
}

float flength(vec3 x) {
	return fsqrt(dot(x, x));
}

float flength(vec4 x) {
	return fsqrt(dot(x, x));
}


float facos(float x) { // No matrix with under 3% error
	// [Eberly2014] GPGPU Programming for Games and Science
	float res = -0.156583 * abs(x) + PI * 0.5;
	res *= fsqrt(1.0 - abs(x));
	return x >= 0 ? res : PI - res;
}