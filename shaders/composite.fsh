#version 410 compatibility
#define composite0
#define fsh
#define ShaderStage 0
#include "/lib/Syntax.glsl"

/* DRAWBUFFERS:6 */

const bool shadowtex1Mipmap    = true;
const bool shadowcolor0Mipmap  = true;
const bool shadowcolor1Mipmap  = true;

const bool shadowtex1Nearest   = true;
const bool shadowcolor0Nearest = false;
const bool shadowcolor1Nearest = false;

uniform sampler2D colortex0;
uniform sampler2D colortex4;
uniform sampler2D colortex5;
uniform sampler2D gdepthtex;
uniform sampler2D depthtex1;
uniform sampler2D shadowcolor;
uniform sampler2D shadowcolor1;
uniform sampler2D shadowtex1;
uniform sampler2DShadow shadow;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;

uniform vec3 cameraPosition;

uniform float near;
uniform float far;
uniform float viewWidth;
uniform float viewHeight;

uniform int isEyeInWater;

varying vec2 texcoord;

#include "/lib/Settings.glsl"
#include "/lib/Utility.glsl"
#include "/lib/Debug.glsl"
#include "/lib/Uniform/Global_Composite_Variables.glsl"
#include "/lib/Fragment/Masks.fsh"

#define texture2DRaw(x, y) texelFetch(x, ivec2(y * vec2(viewWidth, viewHeight)), 0) // texture2DRaw bypasses downscaled interpolation, which causes issues with encoded buffers

float GetDepth(vec2 coord) {
	return texture2DRaw(gdepthtex, coord).x;
}

float GetDepthLinear(vec2 coord) {	
	return (near * far) / (texture2DRaw(gdepthtex, coord).x * (near - far) + far);
}

vec4 CalculateViewSpacePosition(vec2 coord, float depth) {
	vec4 position  = gbufferProjectionInverse * vec4(vec3(coord, depth) * 2.0 - 1.0, 1.0);
	     position /= position.w;
	
	return position;
}

vec3 GetNormal(vec2 coord) {
	return DecodeNormal(texture2DRaw(colortex4, coord).xy);
}

float Calculate8x8DitherPattern(vec2 coord, float n) {
	cint[64] ditherPattern = int[64](1, 49, 13, 61,  4, 52, 16, 64,
	                                 33, 17, 45, 29, 36, 20, 48, 32,
	                                 9, 57,  5, 53, 12, 60,  8, 56,
	                                 41, 25, 37, 21, 44, 28, 40, 24,
										               3, 51, 15, 63,  2, 50, 14, 62,
	                                 35, 19, 47, 31, 34, 18, 46, 30,
	                                 11, 59,  7, 55, 10, 58,  6, 54,
	                                 43, 27, 39, 23, 42, 26, 38, 22);

	coord *= vec2(viewWidth, viewHeight);
	vec2 count = floor(mod(coord, n));
	int dither = ditherPattern[int(count.x) + int(count.y) * n];

	return float(dither) / 65.0;
}

#include "/lib/Misc/Bias_Functions.glsl"
#include "/lib/Fragment/Sunlight/GetSunlightShading.fsh"
#include "/lib/Fragment/Sunlight/ComputeHardShadows.fsh"

#ifndef GI_ENABLED
	#define ComputeGlobalIllumination(a, b, c, d, e, f) vec3(0.0)
#elif GI_MODE == 1
vec3 ComputeGlobalIllumination(vec4 position, vec3 normal, float skyLightmap, cfloat radius, vec2 noise, Mask mask) {
	float lightMult = skyLightmap;
	
#ifdef GI_BOOST
	float sunlight  = GetLambertianShading(normal, mask);
	      sunlight *= skyLightmap;
	      sunlight  = ComputeHardShadows(position, sunlight);
	
	lightMult = 1.0 - sunlight * 4.0;
#endif
	
	if (lightMult < 0.05) return vec3(0.0);
	
	float LodCoeff = clamp01(1.0 - length(position.xyz) / shadowDistance);
	
	float depthLOD	= 2.0 * LodCoeff;
	float sampleLOD	= 5.0 * LodCoeff;
	
	vec4 shadowViewPosition = shadowViewMatrix * gbufferModelViewInverse * position;
	
	position = shadowProjection * shadowViewPosition;
	normal   = mat3(shadowViewMatrix) * mat3(gbufferModelViewInverse) * -normal;
	
	vec3 projMult = mat3(shadowProjectionInverse) * -vec3(1.0, 1.0, 8.0);
	vec3 projDisp = shadowViewPosition.xyz - shadowProjectionInverse[3].xyz - vec3(0.0, 0.0, 0.5 * projMult.z);
	
	cvec3 sampleMax = vec3(0.0, 0.0, pow(radius, 2));
	
	cfloat brightness = 12.5 * pow(radius, 2) * GI_BRIGHTNESS * SUN_LIGHT_LEVEL;
	cfloat scale      = radius / 256.0;
	
	vec3 GI = vec3(0.0);
	
	#include "/lib/Samples/GI.glsl"
	
	for (int i = 0; i < GI_SAMPLE_COUNT; i++) {
		vec2 offset = samples[i] * scale;
		
		vec3 samplePos = vec3(position.xy + offset, 0.0);
		
		vec2 mapPos = BiasShadowMap(samplePos.xy) * 0.5 + 0.5;
		
		samplePos.z = texture2DLod(shadowtex1, mapPos, depthLOD).x;
		
		vec3 sampleDiff = samplePos * projMult + projDisp.xyz;
		
		float sampleLengthSqrd = lengthSquared(sampleDiff);
		
		vec3 shadowNormal;
		     shadowNormal.xy = texture2DLod(shadowcolor1, mapPos, sampleLOD).xy * 2.0 - 1.0;
		     shadowNormal.z  = sqrt(1.0 - lengthSquared(shadowNormal.xy));
		
		vec3 lightCoeffs   = vec3(inversesqrt(sampleLengthSqrd) * sampleDiff * mat2x3(normal, shadowNormal), sampleLengthSqrd);
		     lightCoeffs   = max(lightCoeffs, sampleMax);
		     lightCoeffs.x = mix(lightCoeffs.x, 1.0, GI_TRANSLUCENCE);
		     lightCoeffs.y = sqrt(lightCoeffs.y);
		
		vec3 flux = pow(texture2DLod(shadowcolor, mapPos, sampleLOD).rgb, vec3(2.2));
		
		GI += flux * lightCoeffs.x * lightCoeffs.y / lightCoeffs.z;
	}
	
	GI /= GI_SAMPLE_COUNT;
	
	return GI * lightMult * brightness;
}
#endif

void main() {
	float depth0 = GetDepth(texcoord);
	
	if (depth0 >= 1.0) { discard; }
	
	
#ifdef COMPOSITE0_NOISE
	vec2 noise2D = Calculate8x8DitherPattern(texcoord * COMPOSITE0_SCALE, 8.0) * 2.0 - 1.0;
#else
	vec2 noise2D = vec2(0.0);
#endif
	
	
	vec2  buffer0     = Decode16(texture2D(colortex4, texcoord).b);
	float smoothness  = buffer0.r;
	float skyLightmap = buffer0.g;
	
	Mask mask = CalculateMasks(Decode16(texture2D(colortex5, texcoord).r).g);
	
	float depth1 = (mask.hand > 0.5 ? depth0 : texture2DRaw(depthtex1, texcoord).x);
	
	vec4 viewSpacePosition0 = CalculateViewSpacePosition(texcoord, depth0);
	vec4 viewSpacePosition1 = CalculateViewSpacePosition(texcoord, depth1);
	
	if (depth0 != depth1) {
		mask.transparent = 1.0;
		mask.water       = float(texture2D(colortex0, texcoord).r >= 0.5);
	}
	
	vec3 normal = DecodeNormal(texture2D(colortex4, texcoord).xy);
	
	
	if (depth1 >= 1.0 || isEyeInWater != mask.water)
		{ gl_FragData[0] = vec4(vec3(0.0), 1.0); exit(); return; }
	
	
	vec3 GI = ComputeGlobalIllumination(viewSpacePosition1, normal, skyLightmap, GI_RADIUS * 2.0, noise2D, mask);
	
	
	gl_FragData[0] = vec4(pow(GI * 0.2, vec3(1.0 / 2.2)), 1.0);
	
	exit();
}
