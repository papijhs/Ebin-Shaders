#include "/../shaders/lib/GLSL_Version.glsl"
#define composite0
#define fsh
#define world0
#define ShaderStage 0
#include "/../shaders/lib/Syntax.glsl"

const bool shadowtex1Mipmap    = true;
const bool shadowcolor0Mipmap  = true;
const bool shadowcolor1Mipmap  = true;

const bool shadowtex1Nearest   = true;
const bool shadowcolor0Nearest = true;
const bool shadowcolor1Nearest = false;

uniform sampler2D colortex0;
uniform sampler2D colortex4;
uniform sampler2D gdepthtex;
uniform sampler2D depthtex1;
uniform sampler2D noisetex;
uniform sampler2D shadowcolor;
uniform sampler2D shadowcolor1;
uniform sampler2D shadowtex1;
uniform sampler2DShadow shadow;

uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;

uniform vec3 cameraPosition;

uniform float near;
uniform float far;
uniform float viewWidth;
uniform float viewHeight;
uniform float frameTimeCounter;

uniform int isEyeInWater;

varying vec2 texcoord;

#include "/../shaders/lib/Settings.glsl"
#include "/../shaders/lib/Utility.glsl"
#include "/../shaders/lib/Debug.glsl"
#include "/../shaders/lib/Uniform/Projection_Matrices.fsh"
#include "/../shaders/lib/Uniform/Shading_Variables.glsl"
#include "/../shaders/lib/Uniform/Shadow_View_Matrix.fsh"
#include "/../shaders/lib/Fragment/Masks.fsh"

float GetDepth(vec2 coord) {
	return textureRaw(gdepthtex, coord).x;
}

float GetDepthLinear(vec2 coord) {	
	return (near * far) / (textureRaw(gdepthtex, coord).x * (near - far) + far);
}

vec3 CalculateViewSpacePosition(vec3 screenPos) {
	screenPos = screenPos * 2.0 - 1.0;
	
	return projMAD(projInverseMatrix, screenPos) / (screenPos.z * projInverseMatrix[2].w + projInverseMatrix[3].w);
}

vec3 GetNormal(vec2 coord) {
	return DecodeNormal(textureRaw(colortex4, coord).xy);
}


vec2 GetDitherred2DNoise(vec2 coord, float n) { // Returns a random noise pattern ranging {-1.0 to 1.0} that repeats every n pixels
	coord *= vec2(viewWidth, viewHeight);
	coord  = mod(coord, vec2(n));
	return texelFetch(noisetex, ivec2(coord), 0).xy;
}

#include "/../shaders/lib/Misc/Bias_Functions.glsl"
#include "/../shaders/lib/Fragment/Sunlight_Shading.fsh"

#ifndef GI_ENABLED
	#define ComputeGlobalIllumination(a, b, c, d, e, f) vec3(0.0)
#else
vec3 ComputeGlobalIllumination(vec3 worldSpacePosition, vec3 normal, float skyLightmap, cfloat radius, vec2 noise, Mask mask) {
	float distCoeff = GetDistanceCoeff(worldSpacePosition);
	
	float lightMult = skyLightmap * (1.0 - distCoeff);
	
#ifdef GI_BOOST
	float sunlight = GetLambertianShading(normal, worldLightVector, mask) * skyLightmap;
	      sunlight = ComputeSunlight(worldSpacePosition, sunlight);
	
	lightMult = (pow2(skyLightmap) * 0.9 + 0.1) * (1.0 - distCoeff) - sunlight * 4.0;
#endif
	
	if (lightMult < 0.05) return vec3(0.0);
	
	float LodCoeff = clamp01(1.0 - length(worldSpacePosition) / shadowDistance);
	
	float depthLOD	= 2.0 * LodCoeff;
	float sampleLOD	= 5.0 * LodCoeff;
	
	vec3 shadowViewPosition = transMAD(shadowViewMatrix, worldSpacePosition + gbufferModelViewInverse[3].xyz);
	
	vec2 basePos = shadowViewPosition.xy * diagonal2(shadowProjection) + shadowProjection[3].xy;
	
	normal = mat3(shadowViewMatrix) * -normal;
	
	vec3 projMult = mat3(shadowProjectionInverse) * -vec3(1.0, 1.0, zShrink * 2.0);
	vec3 projDisp = shadowViewPosition.xyz - shadowProjectionInverse[3].xyz - vec3(0.0, 0.0, 0.5 * projMult.z);
	
	cvec3 sampleMax = vec3(0.0, 0.0, radius * radius);
	
	cfloat brightness = 1.0 * radius * radius * GI_BRIGHTNESS * SUN_LIGHT_LEVEL;
	cfloat scale      = radius / 256.0;
	
	noise *= scale;
	
	vec3 GI = vec3(0.0);
	
	#include "/../shaders/lib/Samples/GI.glsl"
	
	float translucent = clamp01(GI_TRANSLUCENCE + mask.translucent);
	
	for (int i = 0; i < GI_SAMPLE_COUNT; i++) {
		vec2 offset = samples[i] * scale + noise;
		
		if (dot(offset.xy, normal.xy) - mask.translucent >= 0.0) continue; // Faux-hemisphere
		
		vec3 samplePos = vec3(basePos.xy + offset, 0.0);
		
		vec2 mapPos = BiasShadowMap(samplePos.xy) * 0.5 + 0.5;
		
		samplePos.z = texture2DLod(shadowtex1, mapPos, depthLOD).x;
		
		vec3 sampleDiff = samplePos * projMult + projDisp.xyz;
		
		float sampleLengthSqrd = length2(sampleDiff);
		
		vec3 shadowNormal;
		     shadowNormal.xy = texture2DLod(shadowcolor1, mapPos, sampleLOD).xy * 2.0 - 1.0;
		     shadowNormal.z  = sqrt(1.0 - length2(shadowNormal.xy));
		
		vec3 lightCoeffs   = vec3(finversesqrt(sampleLengthSqrd) * sampleDiff * mat2x3(normal, shadowNormal), sampleLengthSqrd);
		     lightCoeffs   = max(lightCoeffs, sampleMax);
		     lightCoeffs.x = mix(lightCoeffs.x, 1.0, translucent);
		     lightCoeffs.y = sqrt(lightCoeffs.y);
		
		vec3 flux = texture2DLod(shadowcolor, mapPos, sampleLOD).rgb;
		
		GI += flux * (lightCoeffs.x * lightCoeffs.y * rcp(lightCoeffs.z));
	}
	
	GI /= GI_SAMPLE_COUNT;
	
	return GI * lightMult * brightness;
}
#endif

vec2 Hammersley(int i, int N) {
	return vec2(float(i) / float(N), float(bitfieldReverse(i)) * 2.3283064365386963e-10);
}

vec2 Circlemap(vec2 p) {
	p.y *= TAU;
	return vec2(cos(p.y), sin(p.y)) * p.x;
}

#define AO_SAMPLE_COUNT 6 // [3 4 5 6 8 12 16]
#define AO_RADIUS 1.30 // [0.70 0.85 1.00 1.15 1.30 1.50]
#define AO_INTENSITY 1.00 // [0.25 0.50 0.75 1.00 1.50 2.00 4.00]

float ContinuityAO(vec3 vPos, vec3 normal) {
#ifndef AO_ENABLED
	return 1.0;
#endif
	
	cint steps = AO_SAMPLE_COUNT;
	cfloat r = AO_RADIUS;
	cfloat rInv = 1.0 / r;
	
	vec2 p  = gl_FragCoord.xy / COMPOSITE0_SCALE + 1.0 / vec2(viewWidth, viewHeight);
	     p /= vec2(viewWidth, viewHeight);
	
	int x = int(gl_FragCoord.x) % 4;
	int y = int(gl_FragCoord.y) % 4;
	int index = (x << 2) + y + 1;
	
	vPos = CalculateViewSpacePosition(vec3(p, textureRaw(depthtex1, p).x));
	
	vec2 clipRadius = r * vec2(viewHeight / viewWidth, 1.0) / length(vPos);
	
	float nvisibility = 0.0;
	
	for (int i = 0; i < steps; i++) {
		vec2 circlePoint = Circlemap(Hammersley(i * 15 + index, 16 * steps)) * clipRadius;
		
		vec2 p1 = p + circlePoint;
		vec2 p2 = p + circlePoint * 0.25;
		
		vec3 o  = CalculateViewSpacePosition(vec3(p1, textureRaw(depthtex1, p1).x)) - vPos;
		vec3 o2 = CalculateViewSpacePosition(vec3(p2, textureRaw(depthtex1, p2).x)) - vPos;
		
		vec2 len = vec2(length(o), length(o2));
		
		vec2 ratio = clamp01(len * rInv - 1.0); // (len - r) / r
		
		nvisibility += clamp01(1.0 - max(dot(o, normal) / len.x - ratio.x, dot(o2, normal) / len.y - ratio.y));
	}
	
	nvisibility /= float(steps);
	
	return clamp01(mix(1.0, nvisibility, AO_INTENSITY));
}

vec2 ComputeVolumetricLight(vec3 position, vec3 frontPos, vec2 noise, float waterMask) {
#ifndef VOLUMETRIC_LIGHT
	return vec2(0.0);
#endif
	
	vec3 ray = normalize(position);
	
	vec3 shadowStep = diagonal3(shadowProjection) * (mat3(shadowViewMatrix) * ray);
	
	ray = projMAD(shadowProjection, transMAD(shadowViewMatrix, ray + gbufferModelViewInverse[3].xyz));
	
#ifdef LIMIT_SHADOW_DISTANCE
	cfloat maxSteps = min(200.0, shadowDistance);
#else
	cfloat maxSteps = 200.0;
#endif
	
	float end    = min(length(position), maxSteps);
	float count  = 1.0;
	vec2  result = vec2(0.0);
	
	float frontLength = length(frontPos);
	
	while (count < end) {
		result += shadow2D(shadow, BiasShadowProjection(ray) * 0.5 + 0.5).x * mix(vec2(1.0, 0.0), clamp01(vec2(1.0, -1.0) * (frontLength - count++)), waterMask);
		ray += shadowStep;
	}
	
	result = isEyeInWater == 0 ? result.xy : result.yx;
	
	return result / maxSteps;
}

/* DRAWBUFFERS:56 */
#include "/../shaders/lib/Exit.glsl"

void main() {
	float depth0 = GetDepth(texcoord);
	
#ifndef VOLUMETRIC_LIGHT
	if (depth0 >= 1.0) { discard; }
#endif
	
	
#ifdef COMPOSITE0_NOISE
	vec2 noise2D = GetDitherred2DNoise(texcoord * COMPOSITE0_SCALE, 4.0) * 2.0 - 1.0;
#else
	vec2 noise2D = vec2(0.0);
#endif
	
	
	vec2 texure4 = textureRaw(colortex4, texcoord).rg;
	
	vec4  decode4       = Decode4x8F(texure4.r);
	Mask  mask          = CalculateMasks(decode4.r);
	float smoothness    = decode4.g;
	float torchLightmap = decode4.b;
	float skyLightmap   = decode4.a;
	
	float depth1 = (mask.hand > 0.5 ? depth0 : textureRaw(depthtex1, texcoord).x);
	
	mat2x3 backPos;
	backPos[0] = CalculateViewSpacePosition(vec3(texcoord, depth1));
	backPos[1] = mat3(gbufferModelViewInverse) * backPos[0];
	
	mat2x3 frontPos;
	frontPos[0] = CalculateViewSpacePosition(vec3(texcoord, depth0));
	frontPos[1] = mat3(gbufferModelViewInverse) * frontPos[0];
	
	if (depth0 != depth1)
		mask.water = DecodeWater(textureRaw(colortex0, texcoord).g);
	
	vec2 VL = ComputeVolumetricLight(backPos[1], frontPos[1], noise2D, mask.water);
	
	gl_FragData[1] = vec4(VL, 0.0, 0.0);
	
	if (depth1 >= 1.0) // Back surface is sky
		{ gl_FragData[0] = vec4(0.0, 0.0, 0.0, 1.0); exit(); return; }
	
	
	vec3 normal = DecodeNormal(texure4.g, 11);
	
	float AO = ContinuityAO(backPos[0], normal * mat3(gbufferModelViewInverse));
	
	if (isEyeInWater != mask.water) // If surface is in water
		{ gl_FragData[0] = vec4(0.0, 0.0, 0.0, AO); exit(); return; }
	
	
	vec3 GI = ComputeGlobalIllumination(backPos[1], normal, skyLightmap, GI_RADIUS * 2.0, noise2D, mask);
	
	gl_FragData[0] = vec4(sqrt(GI * 0.2), AO);
	
	exit();
}
