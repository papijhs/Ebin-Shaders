//These functions guarentee the driver will always use the fastest avalible method for intense computations and approximations, even if these do not affect performance
//On some hardware it at least guarentees that the driver can never break performance.
// [Drobot2014a] Low Level Optimisations for GNC
#define fsqrt(x) intBitsToFloat(0x1FBD1DF5 + (floatBitsToInt(x) >> 1)) // Error of 1.42% Literally Free

#define finversesqrt(x) intBitsToFloat(0x5F33E79F - (floatBitsToInt(x) >> 1)) // Error of 1.62%

#define flength(x) fsqrt(dot(x, x))

float facos(float x) { // No matrix with under 3% error
	// [Eberly2014] GPGPU Programming for Games and Science
	float ax = abs(x);
	float res = -0.156583 * ax + PI * 0.5;
	res *= fsqrt(1.0 - ax);
	return x >= 0 ? res : PI - res;
}