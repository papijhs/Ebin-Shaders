//#define FAST_MATH

#ifdef FAST_MATH
	#define fsqrt(x) intBitsToFloat(0x1FBD1DF5 + (floatBitsToInt(x) >> 1u)) // Error of 1.42%
	
	#define finversesqrt(x) intBitsToFloat(0x5F33E79F - (floatBitsToInt(x) >> 1u)) // Error of 1.62%
	
	float facos(float x) { // Under 3% error
		float ax = abs(x);
		float res = -0.156583 * ax + PI * 0.5;
		res *= fsqrt(1.0 - ax);
		return x >= 0 ? res : PI - res;
	}
#else
	#define fsqrt(x) sqrt(x)
	#define finversesqrt(x) inversesqrt(x)
	#define facos(x) acos(x)
#endif


float flength(vec2 x) {
	return fsqrt(dot(x, x));
}

float flength(vec3 x) {
	return fsqrt(dot(x, x));
}

float flength(vec4 x) {
	return fsqrt(dot(x, x));
}
