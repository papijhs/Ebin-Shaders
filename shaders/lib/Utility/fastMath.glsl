float fsqrt(float x) { // Error of 1.42%
    //  [Drobot2014a] Low Level Optimisations for GNC
    return intBitsToFloat(0x1FBD1DF5 + (floatBitsToInt(x) >> 1)); //Literally Free.
}

vec2 fsqrt(vec2 x) { // Error of 1.42%
    //  [Drobot2014a] Low Level Optimisations for GNC
    return intBitsToFloat(0x1FBD1DF5 + (floatBitsToInt(x) >> 1)); //Literally Free.
}

vec3 fsqrt(vec3 x) { // Error of 1.42%
    //  [Drobot2014a] Low Level Optimisations for GNC
    return intBitsToFloat(0x1FBD1DF5 + (floatBitsToInt(x) >> 1)); //Literally Free.
}

vec4 fsqrt(vec4 x) { // Error of 1.42%
    //  [Drobot2014a] Low Level Optimisations for GNC
    return intBitsToFloat(0x1FBD1DF5 + (floatBitsToInt(x) >> 1)); //Literally Free.
}

////////////////////////////////////////////////////////////////////////////////

float finversesqrt(float x) { // Error of 1.62%
    return intBitsToFloat(0x5F33E79F - (floatBitsToInt(x) >> 1));
}

vec2 finversesqrt(vec2 x) { // Error of 1.62%
    return intBitsToFloat(0x5F33E79F - (floatBitsToInt(x) >> 1));
}

vec3 finversesqrt(vec3 x) { // Error of 1.62%
    return intBitsToFloat(0x5F33E79F - (floatBitsToInt(x) >> 1));
}

vec4 finversesqrt(vec4 x) { // Error of 1.62%
    return intBitsToFloat(0x5F33E79F - (floatBitsToInt(x) >> 1));
}

////////////////////////////////////////////////////////////////////////////////

float flength(vec2 x) {
    return fsqrt(dot(x, x));
}

float flength(vec3 x) {
    return fsqrt(dot(x, x));
}

float flength(vec4 x) {
    return fsqrt(dot(x, x));
}

////////////////////////////////////////////////////////////////////////////////

float facos(float x) { // No matrix with under 3% error
    //  [Eberly2014] GPGPU Programming for Games and Science
    float res = -0.156583 * abs(x) + PI * 0.5;
    res *= fsqrt(1.0 - abs(x));
    return x >= 0 ? res : PI - res;
}