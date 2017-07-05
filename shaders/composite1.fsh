#version 410 compatibility
#define composite1
#define fsh
#define ShaderStage 1
#include "/lib/Syntax.glsl"

/* DRAWBUFFERS:1465 */

const bool colortex5MipmapEnabled = true;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler2D colortex5;
uniform sampler2D colortex6;
uniform sampler2D gdepthtex;
uniform sampler2D depthtex1;
uniform sampler2D noisetex;
uniform sampler2D shadowtex1;
uniform sampler2DShadow shadow;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowProjection;

uniform vec3 cameraPosition;
uniform vec3 upPosition;

uniform float viewWidth;
uniform float viewHeight;
uniform float frameTimeCounter;
uniform float wetness;
uniform float rainStrength;
uniform float nightVision;
uniform float near;
uniform float far;

uniform ivec2 eyeBrightnessSmooth;

uniform int isEyeInWater;
uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;

varying vec2 texcoord;

flat varying vec2 pixelSize;

#include "/lib/Settings.glsl"
#include "/lib/Utility.glsl"
#include "/lib/Debug.glsl"
#include "/lib/Uniform/Projection_Matrices.fsh"
#include "/lib/Uniform/Shading_Variables.glsl"
#include "/lib/Uniform/Shadow_View_Matrix.fsh"
#include "/lib/Fragment/Masks.fsh"

#include "/UserProgram/centerDepthSmooth.glsl" // Doesn't seem to be enabled unless it's initialized in a fragment.

vec3 GetDiffuse(vec2 coord) {
	return texture2D(colortex1, coord).rgb;
}

float GetDepth(vec2 coord) {
	return texture2D(gdepthtex, coord).x;
}

float GetTransparentDepth(vec2 coord) {
	return texture2D(depthtex1, coord).x;
}

float ExpToLinearDepth(float depth) {
	return 2.0 * near * (far + near - depth * (far - near));
}

vec3 CalculateViewSpacePosition(vec3 screenPos) {
	screenPos = screenPos * 2.0 - 1.0;
	
	return projMAD(projInverseMatrix, screenPos) / (screenPos.z * projInverseMatrix[2].w + projInverseMatrix[3].w);
}

#include "/lib/Fragment/Calculate_Shaded_Fragment.fsh"

void BilateralUpsample(vec3 normal, float depth, out vec4 GI, out vec2 VL) {
	GI = vec4(0.0, 0.0, 0.0, 1.0);
	VL = vec2(1.0);
	
#if !(defined GI_ENABLED || defined AO_ENABLED || defined VOLUMETRIC_LIGHT)
	return;
#endif
	
	vec2 scaledCoord = texcoord * COMPOSITE0_SCALE;
	
	float expDepth = ExpToLinearDepth(depth);
	
	cfloat kernal = 2.0;
	cfloat range = kernal * 0.5 - 0.5;
	
	float totalWeight = 0.0;
	
	vec4 samples = vec4(0.0);
	
#if defined GI_ENABLED || defined AO_ENABLED
	if (depth < 1.0) {
		for (float y = -range; y <= range; y++) {
			for (float x = -range; x <= range; x++) {
				vec2 offset = vec2(x, y) * pixelSize;
				
				float sampleDepth  = ExpToLinearDepth(texture2D(gdepthtex, texcoord + offset * 8.0).x);
				vec3  sampleNormal =     DecodeNormal(texture2D(colortex4, texcoord + offset * 8.0).g, 11);
				
				float weight  = clamp01(1.0 - abs(expDepth - sampleDepth));
					  weight *= abs(dot(normal, sampleNormal)) * 0.5 + 0.5;
					  weight += 0.001;
				
				samples += pow2(texture2DLod(colortex5, scaledCoord + offset * 2.0, 1)) * weight;
				
				totalWeight += weight;
			}
		}
	}
	
	GI = samples / totalWeight; GI.rgb *= 5.0;
	
	samples = vec4(0.0);
	totalWeight = 0.0;
#endif
	
#ifdef VOLUMETRIC_LIGHT
	for (float y = -range; y <= range; y++) {
		for (float x = -range; x <= range; x++) {
			vec2 offset = vec2(x, y) * pixelSize;
			
			float sampleDepth = ExpToLinearDepth(texture2D(gdepthtex, texcoord + offset * 8.0).x);
			float weight = clamp01(1.0 - abs(expDepth - sampleDepth)) + 0.001;
			
			samples.xy += texture2DLod(colortex6, scaledCoord + offset, 0).rg * weight;
			
			totalWeight += weight;
		}
	}
	
	VL = samples.xy / totalWeight;
#endif
}

#include "/lib/Misc/Calculate_Fogfactor.glsl"
#include "/lib/Fragment/Water_Depth_Fog.fsh"
#include "/lib/Fragment/AerialPerspective.fsh"

float CalculateDitherPattern1() {
	const int[16] ditherPattern = int[16] (
		 0,  8,  2, 10,
		12,  4, 14,  6,
		 3, 11,  1,  9,
		15,  7, 13,  5);
	
	vec2 count = vec2(mod(gl_FragCoord.st, vec2(4.0)));
	
	int dither = ditherPattern[int(count.x) + int(count.y) * 4] + 1;
	
	return float(dither) / 17.0;
}

float CalculateSunglow2(vec3 vPos) {
	vec3 npos = normalize(vPos);
	vec3 halfVector2 = normalize(-lightVector + npos);
	float factor = 1.0 - dot(halfVector2, npos);
	
	return factor * factor * factor * factor;
}

float Get2DNoise(vec3 pos) { // 2D slices
	return texture2D(noisetex, pos.xz * noiseResInverse).x;
}

float Get2DStretchNoise(vec3 pos) {
	float zStretch = 15.0 * noiseResInverse;
	
	vec2 coord = pos.xz * noiseResInverse + (floor(pos.y) * zStretch);
	
	return texture2D(noisetex, coord).x;
}

float Get2_5DNoise(vec3 pos) { // 2.5D
	float p = floor(pos.y);
	float f = pos.y - p;
	
	float zStretch = 17.0 * noiseResInverse;
	
	vec2 coord = pos.xz * noiseResInverse + (p * zStretch);
	
	vec2 noise = texture2D(noisetex, coord).xy;
	
	return mix(noise.x, noise.y, f);
}

float Get3DNoise(vec3 pos) { // True 3D
	float p = floor(pos.z);
	float f = pos.z - p;
	
	float zStretch = 17.0 * noiseResInverse;
	
	vec2 coord = pos.xy * noiseResInverse + (p * zStretch);
	
	float xy1 = texture2D(noisetex, coord).x;
	float xy2 = texture2D(noisetex, coord + zStretch).x;
	
	return mix(xy1, xy2, f);
}

vec3 Get3DNoise3D(vec3 pos) {
	float p = floor(pos.z);
	float f = pos.z - p;
	
	float zStretch = 17.0 * noiseResInverse;
	
	vec2 coord = pos.xy * noiseResInverse + (p * zStretch);
	
	vec3 xy1 = texture2D(noisetex, coord).xyz;
	vec3 xy2 = texture2D(noisetex, coord + zStretch).xyz;
	
	return mix(xy1, xy2, f);
}

#define CloudNoise Get3DNoise // [Get2DNoise Get2DStretchNoise Get2_5DNoise Get3DNoise]

float GetCoverage(float coverage, cfloat denseFactor, float clouds) {
	return clamp01((clouds + coverage - 1.0) * denseFactor);
}

mat4x3 cloudMul;
mat4x3 cloudAdd;

vec3 directColor, ambientColor, bouncedColor;

vec4 CloudColor(vec3 worldPosition, cfloat cloudLowerHeight, cfloat cloudDepth, cfloat denseFactor, float coverage, float sunglow) {
	cfloat cloudCenter = cloudLowerHeight + cloudDepth * 0.5;
	
	float cloudAltitudeWeight = clamp01(distance(worldPosition.y, cloudCenter) / (cloudDepth / 2.0));
	      cloudAltitudeWeight = pow(1.0 - cloudAltitudeWeight, 0.33);
	
	vec4 cloud;
	
	mat4x3 p;
	
	cfloat[5] weights = float[5](1.3, -0.7, -0.255, -0.105, 0.04);
	
	vec3 w = worldPosition / 100.0;
	
	p[0] = w * cloudMul[0] + cloudAdd[0];
	p[1] = w * cloudMul[1] + cloudAdd[1];
	
	cloud.a  = CloudNoise(p[0]) * weights[0];
	cloud.a += CloudNoise(p[1]) * weights[1];
	
	if (GetCoverage(coverage, denseFactor, (cloud.a - weights[1]) * cloudAltitudeWeight) < 1.0)
		return vec4(0.0);
	
	p[2] = w * cloudMul[2] + cloudAdd[2];
	p[3] = w * cloudMul[3] + cloudAdd[3];
	
	cloud.a += CloudNoise(p[2]) * weights[2];
	cloud.a += CloudNoise(p[3]) * weights[3];
	cloud.a += CloudNoise(p[3] * cloudMul[3] / 6.0 + cloudAdd[3]) * weights[4];
	
	cloud.a += -(weights[1] + weights[2] + weights[3]);
	cloud.a /= 2.15;
	
	cloud.a = GetCoverage(coverage, denseFactor, cloud.a * cloudAltitudeWeight);
	
	float heightGradient  = clamp01((worldPosition.y - cloudLowerHeight) / cloudDepth);
	float anisoBackFactor = mix(clamp01(pow(cloud.a, 1.6) * 2.5), 1.0, sunglow);
	float sunlight;
	
	/*
	vec3 lightOffset = 0.25 * worldLightVector;
	
	cloudAltitudeWeight = clamp01(distance(worldPosition.y + lightOffset.y * cloudDepth, cloudCenter) / (cloudDepth / 2.0));
	cloudAltitudeWeight = pow(1.0 - cloudAltitudeWeight, 0.3);
	
	sunlight  = CloudNoise(p[0] + lightOffset) * weights[0];
	sunlight += CloudNoise(p[1] + lightOffset) * weights[1];
	if (1.0 - GetCoverage(coverage, denseFactor, (sunlight - weights[1]) * cloudAltitudeWeight) < 1.0)
	{
	sunlight += CloudNoise(p[2] + lightOffset) * weights[2];
	sunlight += CloudNoise(p[3] + lightOffset) * weights[3];
	sunlight += -(weights[1] + weights[2] + weights[3]); }
	sunlight /= 2.15;
	sunlight  = 1.0 - pow(GetCoverage(coverage, denseFactor, sunlight * cloudAltitudeWeight), 1.5);
	sunlight  = (pow4(heightGradient) + sunlight * 0.9 + 0.1) * (1.0 - timeHorizon);
	*/
	
	sunlight  = pow5((worldPosition.y - cloudLowerHeight) / (cloudDepth - 25.0)) + sunglow * 0.005;
	sunlight *= 1.0 + sunglow * 5.0 + pow(sunglow, 0.25);
	
	
	cloud.rgb = mix(ambientColor, directColor, sunlight) + bouncedColor;
	
	return cloud;
}

void swap(io vec3 a, io vec3 b) {
	vec3 swap = a;
	a = b;
	b = swap;
}

void CloudFBM1(cfloat speed) {
	float t = TIME * 0.07 * speed;
	
	cloudMul[0] = vec3(0.5, 0.5, 0.1);
	cloudAdd[0] = vec3(t * 1.0, 0.0, 0.0);
	
	cloudMul[1] = vec3(1.0, 2.0, 1.0);
	cloudAdd[1] = vec3(t * 0.577, 0.0, 0.0);
	
	cloudMul[2] = vec3(6.0, 6.0, 6.0);
	cloudAdd[2] = vec3(t * 5.272, 0.0, t * 0.905);
	
	cloudMul[3] = vec3(18.0);
	cloudAdd[3] = vec3(t * 19.721, 0.0, t * 6.62);
}

void CloudFBM2(cfloat speed) {
	float t = TIME * 0.07 * speed;
	
	cloudMul[0] = vec3(0.5, 0.5, 1.0);
	cloudAdd[0] = vec3(t * 1.0, 0.0, 0.0);
	
	cloudMul[1] = vec3(1.0, 2.0, 1.0);
	cloudAdd[1] = vec3(t * 0.577, 0.0, 0.0);
	
	cloudMul[2] = vec3(6.0, 6.0, 6.0);
	cloudAdd[2] = vec3(t * 5.272, 0.0, t * 0.905);
	
	cloudMul[3] = vec3(18.0);
	cloudAdd[3] = vec3(t * 19.721, 0.0, t * 6.62);
}

void CloudLighting1(float sunglow) {
	directColor  = sunlightColor;
	directColor *= 8.0 * (1.0 + pow4(sunglow) * 10.0) * (1.0 - rainStrength * 0.8);
	
	ambientColor  = mix(sqrt(skylightColor), sunlightColor, 0.15);
	ambientColor *= 2.0 * mix(vec3(1.0), vec3(0.6, 0.8, 1.0), timeNight);
	
	bouncedColor = mix(skylightColor, sunlightColor, 0.5);
}

void CloudLighting2(float sunglow) {
	directColor  = sunlightColor;
	directColor *= 35.0 * (1.0 + pow2(sunglow) * 2.0) * mix(1.0, 0.2, rainStrength);
	
	ambientColor  = mix(sqrt(skylightColor), sunlightColor, 0.5);
	ambientColor *= 0.5 + timeHorizon * 0.5;
	
	directColor += ambientColor * 20.0 * timeHorizon;
	
	bouncedColor = vec3(0.0);
}

void CloudLighting3(float sunglow) {
	directColor  = sunlightColor;
	directColor *= 140.0 * mix(1.0, 0.5, timeNight);
	
	ambientColor = mix(skylightColor, sunlightColor, 0.15) * 7.0;
	
	bouncedColor = vec3(0.0);
}

void RaymarchClouds(io vec4 cloudSum, vec3 position, float sunglow, float samples, cfloat noise, cfloat density, float coverage, cfloat cloudLowerHeight, cfloat cloudDepth) {
	if (cloudSum.a >= 1.0) return;
	
	cfloat cloudUpperHeight = cloudLowerHeight + cloudDepth;
	
	vec3 a, b, rayPosition, rayIncrement;
	
	a = position * ((cloudUpperHeight - cameraPosition.y) / position.y);
	b = position * ((cloudLowerHeight - cameraPosition.y) / position.y);
	
	if (cameraPosition.y < cloudLowerHeight) {
		if (position.y <= 0.0) return;
		
		swap(a, b);
	} else if (cloudLowerHeight <= cameraPosition.y && cameraPosition.y <= cloudUpperHeight) {
		if (position.y < 0.0) swap(a, b);
		
		samples *= abs(a.y) / cloudDepth;
		b = vec3(0.0);
		
		swap(a, b);
	} else {
		if (position.y >= 0.0) return;
	}
	
	rayIncrement = (b - a) / (samples + 1.0);
	rayPosition = a + cameraPosition + rayIncrement * (1.0 + CalculateDitherPattern1() * noise);
	
	coverage *= clamp01(1.0 - length2((rayPosition.xz - cameraPosition.xz) / 10000.0));
	if (coverage <= 0.1) return;
	
	cfloat denseFactor = 1.0 / (1.0 - density);
	
	for (float i = 0.0; i < samples && cloudSum.a < 1.0; i++, rayPosition += rayIncrement) {
		vec4 cloud = CloudColor(rayPosition, cloudLowerHeight, cloudDepth, denseFactor, coverage, sunglow);
		
		cloudSum.rgb += cloud.rgb * (1.0 - cloudSum.a) * cloud.a;
		cloudSum.a += cloud.a;
	}
	
	cloudSum.a = clamp01(cloudSum.a);
}

#define VOLUMETRIC_CLOUDS

#define CLOUD1
#define CLOUD1_START_HEIGHT 400 // [260 300 350 400 450 500 550 600 650 700 750 800 850 900 950 1000]
#define CLOUD1_DEPTH   150 // [50 100 150 200 250 300 350 400 450 500]
#define CLOUD1_SAMPLES  10 // [3 4 5 6 7 8 9 10 15 20 25 30 40 50 100]
#define CLOUD1_NOISE     1.0 // [0.0 1.0]
#define CLOUD1_COVERAGE  0.5 // [0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9]
#define CLOUD1_DENSITY   0.95 // [0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 0.97 0.99]
#define CLOUD1_SPEED     1.0 // [0.25 0.5 1.0 2.5 5.0 10.0]
#define Cloud1FBM CloudFBM1 // [CloudFBM1 CloudFBM2]
#define Cloud1Lighting CloudLighting2 // [CloudLighting1 CloudLighting2 CloudLighting3]

//#define CLOUD2
#define CLOUD2_START_HEIGHT 400 // [260 300 350 400 450 500 550 600 650 700 750 800 850 900 950 1000]
#define CLOUD2_DEPTH   150 // [50 100 150 200 250 300 350 400 450 500]
#define CLOUD2_SAMPLES  10 // [3 4 5 6 7 8 9 10 15 20 25 30 40 50 100]
#define CLOUD2_NOISE     1.0 // [0.0 1.0]
#define CLOUD2_COVERAGE  0.5 // [0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9]
#define CLOUD2_DENSITY   0.95 // [0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 0.97 0.99]
#define CLOUD2_SPEED     1.0 // [0.25 0.5 1.0 2.5 5.0 10.0]
#define Cloud2FBM CloudFBM1 // [CloudFBM1 CloudFBM2]
#define Cloud2Lighting CloudLighting2 // [CloudLighting1 CloudLighting2 CloudLighting3]

//#define CLOUD3
#define CLOUD3_START_HEIGHT 400 // [260 300 350 400 450 500 550 600 650 700 750 800 850 900 950 1000]
#define CLOUD3_DEPTH   150 // [50 100 150 200 250 300 350 400 450 500]
#define CLOUD3_SAMPLES  10 // [3 4 5 6 7 8 9 10 15 20 25 30 40 50 100]
#define CLOUD3_NOISE     1.0 // [0.0 1.0]
#define CLOUD3_COVERAGE  0.5 // [0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9]
#define CLOUD3_DENSITY   0.95 // [0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 0.97 0.99]
#define CLOUD3_SPEED     1.0 // [0.25 0.5 1.0 2.5 5.0 10.0]
#define Cloud3FBM CloudFBM1 // [CloudFBM1 CloudFBM2]
#define Cloud3Lighting CloudLighting2 // [CloudLighting1 CloudLighting2 CloudLighting3]

vec4 CalculateClouds3(mat2x3 position, float depth) {
#ifndef VOLUMETRIC_CLOUDS
	return vec4(0.0);
#endif
	
	if (depth < 1.0) return vec4(0.0);
	const ivec2[4] offsets = ivec2[4](ivec2(2), ivec2(-2, 2), ivec2(2, -2), ivec2(-2));
//	if (all(lessThan(textureGatherOffsets(depthtex1, texcoord, offsets, 0), vec4(1.0)))) return vec4(0.0);
	
	float sunglow  = pow8(clamp01(dotNorm(position[1], worldLightVector) - 0.01)) * pow4(max(timeDay, timeNight));
	float coverage = 0.0;
	
	vec4 cloudSum = vec4(0.0);
	
#ifdef CLOUD1
	coverage = CLOUD1_COVERAGE + rainStrength * 0.335;
	Cloud1FBM(CLOUD1_SPEED);
	Cloud1Lighting(sunglow);
	RaymarchClouds(cloudSum, position[1], sunglow, CLOUD1_SAMPLES, CLOUD1_NOISE, CLOUD1_DENSITY, coverage, CLOUD1_START_HEIGHT, CLOUD1_DEPTH);
#endif
	
#ifdef CLOUD2
	coverage = CLOUD2_COVERAGE + rainStrength * 0.335;
	Cloud2FBM(CLOUD2_SPEED);
	Cloud2Lighting(sunglow);
	RaymarchClouds(cloudSum, position[1], sunglow, CLOUD2_SAMPLES, CLOUD2_NOISE, CLOUD2_DENSITY, coverage, CLOUD2_START_HEIGHT, CLOUD2_DEPTH);
#endif
	
#ifdef CLOUD3
	coverage = CLOUD3_COVERAGE + rainStrength * 0.335;
	Cloud3FBM(CLOUD2_SPEED);
	Cloud3Lighting(sunglow);
	RaymarchClouds(cloudSum, position[1], sunglow, CLOUD3_SAMPLES, CLOUD3_NOISE, CLOUD3_DENSITY, coverage, CLOUD3_START_HEIGHT, CLOUD3_DEPTH);
#endif
	
	cloudSum.rgb *= 0.1;
	
	return cloudSum;
}

void main() {
	vec2 texure4 = ScreenTex(colortex4).rg;
	
	vec4  decode4       = Decode4x8F(texure4.r);
	Mask  mask          = CalculateMasks(decode4.r);
	float smoothness    = decode4.g;
	float torchLightmap = decode4.b;
	float skyLightmap   = decode4.a;
	
	float depth0 = (mask.hand > 0.5 ? 0.9 : GetDepth(texcoord));
	
	vec3 wNormal = DecodeNormal(texure4.g, 11);
	vec3 normal  = wNormal * mat3(gbufferModelViewInverse);
	vec3 waterNormal;
	
	float depth1 = mask.hand > 0.5 ? depth0 : GetTransparentDepth(texcoord);
	
	if (depth0 != depth1) {
		vec2 texure0 = texture2D(colortex0, texcoord).rg;
		
		vec4 decode0 = Decode4x8F(texure0.r);
		waterNormal = DecodeNormalU(texure0.g) * mat3(gbufferModelViewInverse);
		
		mask.transparent = 1.0;
		mask.water       = DecodeWater(texure0.g);
		mask.bits.xy     = vec2(1.0, mask.water);
		mask.materialIDs = EncodeMaterialIDs(1.0, mask.bits);

		texure4 = vec2(Encode4x8F(vec4(mask.materialIDs, decode0.r, 0.0, decode0.g)), ReEncodeNormal(texure0.g, 11.0));
	}
	
	vec4 GI; vec2 VL;
	BilateralUpsample(wNormal, depth1, GI, VL);
	
	gl_FragData[1] = vec4(texure4.rg, 0.0, 1.0);
	gl_FragData[2] = vec4(VL.xy, 0.0, 1.0);
	
	
	mat2x3 backPos;
	backPos[0] = CalculateViewSpacePosition(vec3(texcoord, depth1));
	backPos[1] = mat3(gbufferModelViewInverse) * backPos[0];
	
	vec4 cloud = CalculateClouds3(backPos, depth1);
	
	
	gl_FragData[3] = vec4(sqrt(cloud.rgb / 50.0), cloud.a);
	
	if (depth1 - mask.hand >= 1.0) { exit(); return; }
	
	
	vec3 diffuse = GetDiffuse(texcoord);
	vec3 viewSpacePosition0 = CalculateViewSpacePosition(vec3(texcoord, depth0));
	
	
	vec3 composite = CalculateShadedFragment(powf(diffuse, 2.2), mask, torchLightmap, skyLightmap, GI, normal, smoothness, backPos);
	
	if (mask.water > 0.5 || isEyeInWater == 1)
		composite = WaterFog(composite, waterNormal, viewSpacePosition0, backPos[0]);
	
	composite += AerialPerspective(length(backPos[0]), skyLightmap) * (1.0 - mask.water);
	
	gl_FragData[0] = vec4(max0(composite), 1.0);
	
	exit();
}
