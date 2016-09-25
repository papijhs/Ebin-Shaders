float Encode4x8F(in vec4 a) {
	uvec4 v = uvec4(round(clamp01(a) * 255.0)) << uvec4(0, 8, 16, 24);
	
	return uintBitsToFloat(sum4(v));
}

vec4 Decode4x8F(in float encodedbuffer) {
	return vec4(floatBitsToUint(encodedbuffer) >> uvec4(0, 8, 16, 24) & 255) / 255.0;
}

float Encode16(vec2 encodedBuffer) {
	cvec2 encode = vec2(1.0, exp2(8.0));
	
	encodedBuffer = round(encodedBuffer * 255.0);
	
	return dot(encodedBuffer, encode) / (exp2(16.0) - 1.0);
}

vec2 Decode16(float encodedBuffer) {
	cvec2 decode = 1.0 / (exp2(8.0) - 1.0) / vec2(1.0, exp2(8.0));
	
	vec2 decoded;
	
	encodedBuffer *= exp2(16.0) - 1.0;
	
	decoded.r = mod(encodedBuffer, exp2(8.0));
	decoded.g = encodedBuffer - decoded.r;
	
	return decoded * decode;
}

void Decode16(float encodedBuffer, out float buffer0, out float buffer1) {
	cvec2 decode = 1.0 / (exp2(8.0) - 1.0) / vec2(1.0, exp2(8.0));
	
	vec2 decoded;
	
	encodedBuffer *= exp2(16.0) - 1.0;
	
	decoded.r = mod(encodedBuffer, exp2(8.0));
	decoded.g = encodedBuffer - decoded.r;
	
	decoded *= decode;
	
	buffer0 = decoded.r;
	buffer1 = decoded.g;
}

vec3 EncodeColor(vec3 color) { // Prepares the color to be sent through a limited dynamic range pipeline
	return pow(color * 0.001, vec3(1.0 / 2.2));
}

vec3 DecodeColor(vec3 color) {
	return pow(color, vec3(2.2)) * 1000.0;
}

vec2 EncodeNormal(vec3 normal) {
    return vec2(normal.xy * inversesqrt(normal.z * 8.0 + 8.0) + 0.5);
}

vec3 DecodeNormal(vec2 encodedNormal) {
	encodedNormal = encodedNormal * 4.0 - 2.0;
	float f = lengthSquared(encodedNormal);
	float g = sqrt(1.0 - f * 0.25);
	return vec3(encodedNormal * g, 1.0 - f * 0.5);
}
