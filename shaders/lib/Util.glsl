// Start of #include "/lib/Util.glsl"

#define  PI 3.1415926 // Pi
#define RAD 0.0174533 // Degrees per radian

#define TIME frameTimeCounter

cvec3 lumaCoeff = vec3(0.2125, 0.7154, 0.0721);

cfloat e = exp(1.0);


float cubesmooth(in float x) { // Applies a subtle S-shaped curve, domain [0 to 1]
	return x * x * (3.0 - 2.0 * x);
}

vec2 cubesmooth(in vec2 x) {
	return x * x * (3.0 - 2.0 * x);
}

float cosmooth(in float x) { // Same concept as cubesmooth, slightly different distribution
	return 0.5 - cos(x * PI) * 0.5;
}

vec2 cosmooth(in vec2 x) {
	return 0.5 - cos(x * PI) * 0.5;
}


float square(in float x) {
	return dot(x, x);
}

float pow2(in float x) {
	return dot(x, x);
}

float lengthSquared(in vec2 x) {
	return dot(x, x);
}

float lengthSquared(in vec3 x) {
	return dot(x, x);
}

float lengthSquared(in vec4 x) {
	return dot(x, x);
}

float pow8(in float x) {
	x *= x;
	x *= x;
	return x * x;
}

float root8(in float x) {
	return sqrt(sqrt(sqrt(x)));
}

float length8(in vec2 x) {
	return root8(pow8(x.x) + pow8(x.y));
}


float clamp01(in float x) {
	return clamp(x, 0.0, 1.0);
}

float max0(in float x) {
	return max(x, 0.0);
}

float min1(in float x) {
	return min(x, 1.0);
}


float sum(in vec2 x) { // Sum the components of a vector
	return dot(x, vec2(1.0));
}

float sum(in vec3 x) {
	return dot(x, vec3(1.0));
}

float sum(in vec4 x) {
	return dot(x, vec4(1.0));
}


float Encode24(in vec2 buffer) {
	cvec2 encode = vec2(1.0, exp2(12.0));
	
	buffer = round(buffer * (exp2(12.0) - 1.0));
	
	return dot(buffer, encode);
}

vec2 Decode24(in float buffer) {
	cvec2 decode = 1.0 / (exp2(12.0) - 1.0) / vec2(1.0, exp2(12.0));
	
	vec2 decoded;
	
	decoded.r = mod(buffer, exp2(12.0));
	decoded.g = buffer - decoded.r;
	
	return decoded * decode;
}

float Encode8to32(in float buffer0, in float buffer1, in float buffer2) {
	cvec3 encode = vec3(1.0, exp2(8.0), exp2(16.0));
	
	vec3 buffer = vec3(buffer0, buffer1, buffer2);
	     buffer = round(buffer * 255.0);
	
	return dot(buffer, encode);
}

void Decode32to8(in float buffer, out float buffer0, out float buffer1, out float buffer2) {
	buffer0 = mod(buffer          , exp2( 8.0));
	buffer1 = mod(buffer - buffer0, exp2(16.0));
	buffer2 = buffer - buffer1 - buffer0;
	
	buffer0 /= 255.0;
	buffer1 /= 255.0 * exp2( 8.0);
	buffer2 /= 255.0 * exp2(16.0);
}

vec3 EncodeColor(in vec3 color) { // Prepares the color to be sent through a limited dynamic range pipeline
	return pow(color * 0.001, vec3(1.0 / 2.2));
}

vec3 DecodeColor(in vec3 color) {
	return pow(color, vec3(2.2)) * 1000.0;
}

vec2 EncodeNormal(vec3 normal) {
    float p = sqrt(normal.z * 8.0 + 8.0);
    return vec2(normal.xy / p + 0.5);
}

vec3 DecodeNormal(vec2 encodedNormal) {
    vec2 fenc = encodedNormal * 4.0 - 2.0;
	float f = lengthSquared(fenc);
	float g = sqrt(1.0 - f * 0.25);
	return vec3(fenc * g, 1.0 - f * 0.5);
}


vec3 SetSaturationLevel(in vec3 color, in float level) {
	float luminance = max(0.1175, dot(color, lumaCoeff));
	
	return mix(vec3(luminance), color, level);
}


void rotate(inout vec2 vector, in float radians) {
	vector *= mat2(
		cos(radians), -sin(radians),
		sin(radians),  cos(radians));
}

void rotateDeg(inout vec2 vector, in float degrees) {
	degrees = radians(degrees);
	
	vector *= mat2(
		cos(degrees), -sin(degrees),
		sin(degrees),  cos(degrees));
}

// End of #include "/lib/Util.glsl"