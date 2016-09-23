#define  PI 3.1415926 // Pi
#define RAD 0.0174533 // Degrees per radian

#ifdef FREEZE_TIME
	#define TIME 0.0
#else
	#define TIME frameTimeCounter
#endif

cvec4 swizzle = vec4(1.0, 0.0, -1.0, 0.5);

cvec3 lumaCoeff = vec3(0.2125, 0.7154, 0.0721);

#define diagonal2(mat) vec3(mat[0].x, mat[1].y)
#define diagonal3(mat) vec3(mat[0].x, mat[1].y, mat[2].z)

#define transMAD(mat, x) (mat3(mat) * x + mat[3].xyz)
#define  projMAD(mat, x) (x * diagonal3(mat) + mat[3].xyz)


#include "/lib/Utility/smoothing.glsl"

#include "/lib/Utility/length.glsl"

#include "/lib/Utility/clamping.glsl"

#include "/lib/Utility/encoding.glsl"

#include "/lib/Utility/rotation.glsl"

#include "/lib/Utility/blending.glsl"

#include "/lib/Utility/fastMath.glsl"


float pow2(float x) {
	return dot(x, x);
}

vec2 clampScreen(vec2 coord, vec2 pixel) {
	return clamp(coord, pixel, 1.0 - pixel);
}

vec3 SetSaturationLevel(vec3 color, float level) {
	float luminance = max(0.1175, dot(color, lumaCoeff));
	
	return mix(vec3(luminance), color, level);
}
