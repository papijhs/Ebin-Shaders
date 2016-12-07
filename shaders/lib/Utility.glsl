#define  PI 3.14159265358979323846264338327950288419 // Pi
#define RAD 0.0174533 // Degrees per radian

#ifdef FREEZE_TIME
	#define TIME 0.0
#else
	#define TIME frameTimeCounter
#endif

cvec4 swizzle = vec4(1.0, 0.0, -1.0, 0.5);

cvec3 lumaCoeff = vec3(0.2125, 0.7154, 0.0721);

#define sum4(v) ((v.x + v.y) + (v.z + v.w))

#define diagonal2(mat) vec2((mat)[0].x, (mat)[1].y)
#define diagonal3(mat) vec3((mat)[0].x, (mat)[1].y, mat[2].z)

#define transMAD(mat, v) (     mat3(mat) * (v) + (mat)[3].xyz)
#define  projMAD(mat, v) (diagonal3(mat) * (v) + (mat)[3].xyz)

#define textureRaw(samplr, coord) texelFetch(samplr, ivec2((coord) * vec2(viewWidth, viewHeight)), 0)
#define ScreenTex(samplr) texelFetch(samplr, ivec2(gl_FragCoord.st), 0)

#if !defined gbuffers_shadow
	#define cameraPosition() (vec3(mod(cameraPosition.x + 12345.0, 987654.0), cameraPosition.y, mod(cameraPosition.z + 12345.0, 987654.0)) + gbufferModelViewInverse[3].xyz)
#else
	#define cameraPosition() vec3(mod(cameraPosition.x + 12345.0, 987654.0), cameraPosition.y, mod(cameraPosition.z + 12345.0, 987654.0))
#endif


#include "/lib/Utility/fastMath.glsl"

#include "/lib/Utility/smoothing.glsl"

#include "/lib/Utility/length.glsl"

#include "/lib/Utility/clamping.glsl"

#include "/lib/Utility/encoding.glsl"

#include "/lib/Utility/blending.glsl"


float pow2(float f) {
	return dot(f, f);
}

vec3 pow2(vec3 f) {
	return f*f;
}

vec2 rotate(in vec2 vector, float radians) {
	return vector *= mat2(
		cos(radians), -sin(radians),
		sin(radians),  cos(radians));
}

vec2 clampScreen(vec2 coord, vec2 pixel) {
	return clamp(coord, pixel, 1.0 - pixel);
}

vec3 SetSaturationLevel(vec3 color, float level) {
	color = clamp01(color);
	
	float luminance = dot(color, lumaCoeff);
	
	return mix(vec3(luminance), color, level);
}

vec3 hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}


vec3 L2sRGB(vec3 c) {
	vec3 sRGBLo = c * 12.92;
	vec3 sRGBHi = (pow(abs(c), vec3(1.0/2.4)) * 1.055) - 0.055;
	vec3 sRGB = mix(sRGBHi, sRGBLo, lessThanEqual(c, vec3(0.0031308)));

	return sRGB;
}

vec3 sRGB2L(vec3 sRGBCol) {
	vec3 linearRGBLo  = sRGBCol / 12.92;
	vec3 linearRGBHi  = pow((sRGBCol + 0.055) / 1.055, vec3(2.4));
	vec3 linearRGB    = mix(linearRGBHi, linearRGBLo, lessThanEqual(sRGBCol, vec3(0.04045)));

	return  linearRGB;
}

vec3 RGBfromTemp(float kelvin) {
	float red, green, blue;
	kelvin /= 100.0;

	if(kelvin <= 66) {
		red = 255;
	} else {
		red = kelvin - 60;
		red = 329.698727446 * pow(red, -0.1332047592);
		red = clamp(red, 0.0, 255.0);
	}

	if(kelvin <= 66) {
		green = kelvin;
		green = 99.4708025861 * log(green) - 161.1195681661;
		green = clamp(green, 0.0, 255.0);
	} else {
		green = kelvin - 60;
		green = 288.1221695283 * pow(green, -0.0755148492);
		green = clamp(green, 0.0, 255.0);
	}

	if(kelvin >= 66) {
		blue = 255.0;
	} else {
		blue = kelvin - 10;
		blue = 138.5177312231 * log(blue) - 305.0447927307;
		blue = clamp(blue, 0.0, 255.0);
	}

	return vec3(red, green, blue) / 255.0;
}