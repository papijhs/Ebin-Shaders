float Encode4x8F(in vec4 a) {
	uvec4 v = uvec4(round(clamp01(a) * 255.0)) << uvec4(0u, 8u, 16u, 24u);
	
	return uintBitsToFloat(sum4(v));
}

vec4 Decode4x8F(in float encodedbuffer) {
	return vec4(uvec4(floatBitsToUint(encodedbuffer)) >> uvec4(0u, 8u, 16u, 24u) & 255u) / 255.0;
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
	float f = length2(encodedNormal);
	float g = sqrt(1.0 - f * 0.25);
	return vec3(encodedNormal * g, 1.0 - f * 0.5);
}

float EncodeTBN16(vec3 normal) {
	uvec3 norm = uvec3(round(acos(clamp(normal.xy, -1.0, 1.0)) / PI * 8.0), normal.z >= 0.0);
	
//	if (norm.x == 8) norm.xy = uvec2(0, 1);
//	if (norm.y == 8) norm.xy = uvec2(1, 0);
	
	// 3-way ternary operator
	// flows through 2 condtions left-to-right
	// do-nothing at the end if both conditions are false
	norm.xy = norm.x == 8 ? uvec2(0u, 1u) : norm.y == 8 ? (uvec2(1u, 0u)) : norm.xy;
	// if an angle is 8, its component is -1.0
	// in that case, we set the component to 1.0
	// we then set the other angle to 1 (large component), whereas the other component should really be 0.0
	// so later we know for sure that one component is -1.0, and all the others are 0.0
	
	
	return float(norm.x + norm.y * 8 + norm.z * 64) / 128.0;
}

vec3 DecodeTBN16(float enc) {
	uvec3 norm = uvec3(mod(vec3(enc * 128.0), vec3(8.0, 64.0, 128.0))) >> uvec3(0u, 3u, 6u);
	
//	if (norm.y == 0 && norm.x == 1) norm.xy = uvec2(4, 8); else
//	if (norm.x == 0 && norm.y == 1) norm.xy = uvec2(8, 4);
	
	norm.xy = norm.x == 0 && norm.y == 1 ? uvec2(8u, 4u) : norm.y == 0 && norm.x == 1 ? uvec2(4u, 8u) : norm.xy;
	
	vec3 normal;
	     normal.xy = cos(vec2(norm.xy) * PI / 8.0);
	     normal.z = sqrt(1.0 - length2(normal.xy)) * (float(norm.z) * 2.0 - 1.0);
	
	return normal;
}
