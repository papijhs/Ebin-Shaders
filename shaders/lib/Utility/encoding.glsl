float Encode4x8F(in vec4 a) {
	uvec4 v = uvec4(round(clamp01(a) * 255.0)) << uvec4(0, 8, 16, 24);
	
	return uintBitsToFloat(sum4(v));
}

vec4 Decode4x8F(in float encodedbuffer) {
	return vec4(floatBitsToUint(encodedbuffer) >> uvec4(0, 8, 16, 24) & 255) / 255.0;
}

float Encode2x16F(in vec2 a) {
	uvec2 v = uvec2(round(clamp01(a) * 65535.0)) << uvec2(0, 16);
	
	return uintBitsToFloat(v.x + v.y);
}

vec2 Decode2x16(in float encodedbuffer) {
	return vec2(floatBitsToUint(encodedbuffer) >> uvec2(0, 16) & 65535) / 65535.0;
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

float EncodeNormal(vec3 normal, cfloat bits) {
	normal    = clamp(normal, -1.0, 1.0);
	normal.xy = vec2(atan(normal.x, normal.z), acos(normal.y)) / PI;
	normal.x += 1.0;
	normal.xy = round(normal.xy * exp2(bits));
	
	return normal.x + normal.y * exp2(bits + 2.0);
}

vec3 DecodeNormal(float enc, cfloat bits) {
	vec4 normal;
	
	normal.y    = exp2(bits + 2.0) * floor(enc / exp2(bits + 2.0));
	normal.x    = enc - normal.y;
	normal.xy  /= exp2(vec2(bits, bits * 2.0 + 2.0));
	normal.x   -= 1.0;
	normal.xy  *= PI;
	normal.xwzy = vec4(sin(normal.xy), cos(normal.xy));
	normal.xz  *= normal.w;
	
	return normal.xyz;
}

float EncodeNormalU(vec3 normal, vec3 vertNormal) {
	normal = clamp(normal, -1.0, 1.0);
	normal.xy = vec2(atan(normal.x, normal.z), acos(normal.y)) / PI;
	normal.x += 1.0;
	normal.xy = round(normal.xy * 2048.0);
	normal.y = min(normal.y, 2047.0);
	
	vertNormal = clamp(vertNormal, -1.0, 1.0);
	vertNormal.xy = vec2(atan(vertNormal.x, vertNormal.z), acos(vertNormal.y)) / PI;
	vertNormal.x += 1.0;
	vertNormal.xy = round(vertNormal.xy * vec2(8.0, 16.0));
//	vertNormal.y = min(vertNormal.y, 15.0);
	
	uvec4 enc = uvec4(normal.xy, vertNormal.xy);
	enc.x = enc.x & 4095;
	enc.z = enc.z & 15;
	enc.yzw = enc.yzw << uvec3(12, 23, 27);
	
	return uintBitsToFloat(sum4(enc));
}

vec3 DecodeNormalU(float enc, out vec3 vertNormal) {
	cuvec3 shift  = uvec3(12, 23, 27);
	cuvec3 modulo = uvec3(4095, 2047, 15);
	
	uvec4 e = uvec4(floatBitsToUint(enc));
	e.yzw = e.yzw >> shift;
	e.xyz = e.xyz & modulo.xyz;
	
	vec4 normal;
	
	normal.xy   = e.zw;
	normal.xy  /= vec2(8.0, 16.0);
	normal.x   -= 1.0;
	normal.xy  *= PI;
	normal.xwzy = vec4(sin(normal.xy), cos(normal.xy));
	normal.xz  *= normal.w;
	vertNormal  = normal.xyz;
	
	normal.xy   = e.xy;
	normal.xy  /= 2048.0;
	normal.x   -= 1.0;
	normal.xy  *= PI;
	normal.xwzy = vec4(sin(normal.xy), cos(normal.xy));
	normal.xz  *= normal.w;
	
	return normal.xyz;
}

float ReEncodeNormal(float enc, cfloat bits) {
	uvec2 e = uvec2(floatBitsToUint(enc));
	e.y = e.y >> 12;
	e.xy = e.xy & uvec2(4095, 2047);
	
	vec2 normal    = e.xy;
	     normal.xy = round(normal.xy / 2048.0 * exp2(bits));
	
	return normal.x + normal.y * exp2(bits + 2.0);
}

vec3 DecodeNormalU(float enc) {
	uvec2 e = uvec2(floatBitsToUint(enc));
	e.y = e.y >> 12;
	e.xy = e.xy & uvec2(4095, 2047);
	
	vec4 normal;
	
	normal.xy   = e.xy;
	normal.xy  /= 2048.0;
	normal.x   -= 1.0;
	normal.xy  *= PI;
	normal.xwzy = vec4(sin(normal.xy), cos(normal.xy));
	normal.xz  *= normal.w;
	
	return normal.xyz;
}
