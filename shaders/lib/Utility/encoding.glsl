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

float EncodeNormalU(vec3 normal, cuint bits) {
	cfloat angles = exp2(bits) / PI;
	cuint  pole   = uint(exp2(bits));
	cuvec2 bitPos = uvec2(exp2(vec2(bits, bits * 2)));
	cfloat range  = exp2(-float(bits * 2 + 1));
	
	
	uvec3 norm = uvec3(round(acos(clamp(normal.xy, -1.0, 1.0)) * angles), normal.z >= 0.0);
	
	norm.xy = norm.x == pole ? uvec2(0, 1) : norm.y == pole ? (uvec2(1, 0)) : norm.xy;
	
	return float(norm.x + norm.y * bitPos.x + norm.z * bitPos.y) * range;
}

vec3 DecodeNormalU(float enc, cuint bits) {
	cvec3  ranges = exp2(vec3(bits, bits * 2, bits * 2 + 1));
	cuvec3 shift  = uvec3(0, bits, bits * 2);
	cfloat angles = PI / exp2(bits);
	cuvec2 pole   = uvec2(exp2(vec2(bits, bits - 1)));
	
	uvec3 norm = uvec3(mod(enc * ranges.zzz, ranges)) >> shift;
	
	norm.xy = norm.x == 0 && norm.y == 1 ? pole.xy : norm.y == 0 && norm.x == 1 ? pole.yx : norm.xy;
	
	vec3 normal;
	     normal.xy = cos(vec2(norm.xy) * angles);
	     normal.z = sqrt(1.0 - length2(normal.xy)) * (float(norm.z) * 2.0 - 1.0);
	
	return normal;
}

float EncodeNormal(vec3 normal, cuint bits) {
	cfloat angles = exp2(bits) / PI;
	cfloat max    = exp2(bits);
	cvec3  stack  = exp2(bits * vec3(0.0, 1.0, 2.0)) * exp2(-float(bits * 2 + 1));
	cvec2  pole   = vec2(exp2(bits) - 1.0, 0.0);
	
	
	vec3 norm    = vec3(round(acos(clamp(normal.xy, -1.0, 1.0)) * angles), normal.z >= 0.0);
	     norm.xy = norm.x == max ? pole.xy : norm.y == max ? pole.yx : norm.xy;
	
	return dot(norm, stack);
}

vec3 DecodeNormal(float enc, cuint bits) {
	cvec3  unstack = exp2(bits * -vec3(0.0, 1.0, 2.0));
	cvec3  ranges  = exp2(vec3(bits, bits * 2, bits * 2 + 1));
	cvec2  pole    = exp2(vec2(0.0, bits - 1));
	cfloat max     = exp2(bits) - 2.0;
	cfloat angles  = PI / exp2(bits);
	
	
	vec3 normal     = enc * ranges.zzz;
	     normal.xy -= ranges.xy * floor(normal.xy / ranges.xy); 
	     normal.yz  = floor(normal.yz * unstack.yz);
	
	vec4 e = clamp01(vec4(normal.xy - max, 1.0 - normal.yx));
	
	normal.xy += (e.x * e.z) * pole.xy;
	normal.xy += (e.y * e.w) * pole.yx;
	
	normal.xy = cos(normal.xy * angles);
	normal.z  = sqrt(1.0 - length2(normal.xy)) * (normal.z * 2.0 - 1.0);
	
	return normal;
}
