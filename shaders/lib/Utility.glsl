#define  PI 3.1415926 // Pi
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
	#define cameraPosition (mod(cameraPosition, vec3(100000.0)) + gbufferModelViewInverse[3].xyz)
#else
	#define cameraPosition mod(cameraPosition, vec3(100000.0))
#endif


#include "/lib/Utility/fastMath.glsl"

#include "/lib/Utility/smoothing.glsl"

#include "/lib/Utility/length.glsl"

#include "/lib/Utility/clamping.glsl"

#include "/lib/Utility/encoding.glsl"

#include "/lib/Utility/rotation.glsl"

#include "/lib/Utility/blending.glsl"


float pow2(float f) {
	return dot(f, f);
}

vec2 clampScreen(vec2 coord, vec2 pixel) {
	return clamp(coord, pixel, 1.0 - pixel);
}

vec3 SetSaturationLevel(vec3 color, float level) {
	color = clamp01(color);
	
	float luminance = dot(color, lumaCoeff);
	
	return mix(vec3(luminance), color, level);
}
