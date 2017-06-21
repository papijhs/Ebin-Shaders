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
varying vec2 pixelSize;

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

float CalculateSunglow(vec3 worldSpaceVector) {
	float sunglow = max0(dot(worldSpaceVector, worldLightVector) - 0.01);
	      sunglow = pow(sunglow, 8.0);
	
	return sunglow;
}

float Luma(vec3 color) {
  return dot(color, vec3(0.299, 0.587, 0.114));
}

vec3 ColorSaturate(vec3 base, float saturation) {
    return mix(base, vec3(Luma(base)), -saturation);
}

vec3 LightDesaturation(vec3 color, vec2 lightmap){
	cvec3 nightColor = vec3(0.25, 0.35, 0.7);
	cvec3 torchColor = vec3(0.5, 0.33, 0.15) * 0.1;
	vec3  desatColor = vec3(color.x + color.y + color.z);
	
	desatColor = mix(desatColor * nightColor, mix(desatColor, color, 0.5) * ColorSaturate(torchColor, 0.35) * 40.0, clamp01(lightmap.r * 2.0));
	
	float moonFade = smoothstep(0.0, 0.3, max0(-worldLightVector.y));
	
	float coeff = clamp01(min(moonFade, 0.65) + pow(1.0 - lightmap.g, 1.4));
	
	return mix(color, desatColor, coeff);
}

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

#define CloudNoise1 Get3DNoise // [Get2DNoise Get2DStretchNoise Get2_5DNoise Get3DNoise]

float GetCoverage(float coverage, cfloat density, float clouds) {
	clouds = clamp(clouds + coverage - 1.0, 0.0, 1.0 - density) / (1.0 - density);
	clouds = cubesmooth(clamp01(clouds * 1.1 - 0.1));
	
	return clouds;
}

//#define VOLUMETRIC_CLOUDS
#define VOLUMETRIC_CLOUD_SPEED 1.0 // [0.5 1.0 2.5 5.0 10.0]
#define Cloud3Height 400
#define Vol_Cloud_Coverage 0.48

#define VolCloudSamples 10 // [3 4 5 6 7 8 9 10 15 20 25 30 40 50 100]

cfloat cloudDepth = 150.0;
cfloat cloudUpperHeight = Cloud3Height + (cloudDepth / 2.0);
cfloat cloudLowerHeight = Cloud3Height - (cloudDepth / 2.0);

float rainy = mix(wetness, 1.0, rainStrength);
float baseCoverage = 1.1 * Vol_Cloud_Coverage + rainy * 0.335;

mat4x3 cloudMul;
mat4x3 cloudAdd;

vec4 CloudColor3(vec3 worldPosition, float coverage, float sunglow, vec3 directColor, vec3 ambientColor, vec3 bouncedColor) {
	float cloudAltitudeWeight = clamp01(distance(worldPosition.y, Cloud3Height) / (cloudDepth / 2.0));
	      cloudAltitudeWeight = pow(1.0 - cloudAltitudeWeight, 0.33);
	
	cfloat density = 0.95;
	
	vec4 cloud;
	
	mat4x3 p;
	
	cfloat[5] weights = float[5](1.3, -0.7, -0.255, -0.105, 0.04);
	
	vec3 w = worldPosition / 100.0;
	
	p[0] = w * cloudMul[0] + cloudAdd[0];
	p[1] = w * cloudMul[1] + cloudAdd[1];
	p[2] = w * cloudMul[2] + cloudAdd[2];
	p[3] = w * cloudMul[3] + cloudAdd[3];
	
	cloud.a  = CloudNoise1(p[0]) * weights[0];
	cloud.a += CloudNoise1(p[1]) * weights[1];
	
	if (GetCoverage(coverage, density, (cloud.a - weights[1]) * cloudAltitudeWeight) < 1.0)
		return vec4(0.0);
	
	cloud.a += CloudNoise1(p[2]) * weights[2];
	cloud.a += CloudNoise1(p[3]) * weights[3];
	cloud.a += CloudNoise1(p[3] * cloudMul[3] / 6.0 + cloudAdd[3]) * weights[4];
	
	cloud.a += -(weights[1] + weights[2] + weights[3]);
	cloud.a /= 2.15;
	
	cloud.a = pow(GetCoverage(coverage, density, cloud.a * cloudAltitudeWeight), 1.5);
	
	float heightGradient  = clamp01((worldPosition.y - cloudLowerHeight) / cloudDepth);
	float anisoBackFactor = mix(clamp01(pow(cloud.a, 1.6) * 2.5), 1.0, sunglow);
	float directLightFalloff;
	
	/*
	vec3 lightOffset = 0.25 * worldLightVector;
	
	cloudAltitudeWeight = clamp01(distance(worldPosition.y + lightOffset.y * cloudDepth, Cloud3Height) / (cloudDepth / 2.0));
	cloudAltitudeWeight = pow(1.0 - cloudAltitudeWeight, 0.3);
	
	float sunlight  = CloudNoise1(p[0] + lightOffset) * weights[0];
	      sunlight += CloudNoise1(p[1] + lightOffset) * weights[1];
	if (1.0 - GetCoverage(coverage, density, (sunlight - weights[1]) * cloudAltitudeWeight) < 1.0)
	{     sunlight += CloudNoise1(p[2] + lightOffset) * weights[2];
	      sunlight += CloudNoise1(p[3] + lightOffset) * weights[3];
//	      sunlight += CloudNoise1(p5 - worldLightVector * lightOffset) * weights[4];
	      sunlight += -(weights[1] + weights[2] + weights[3]); }
	      sunlight /= 2.15;
	      sunlight  = 1.0 - pow(GetCoverage(coverage, density, sunlight * cloudAltitudeWeight), 1.5);
	
	directLightFalloff  = (pow4(heightGradient) + sunlight * 0.9 + 0.1) * (1.0 - timeHorizon);
	*/
	
	
//	vec3 color  = mix(ambientColor, directColor, directLightFalloff);
//	     color += bouncedColor * (10.0 * pow8(1.0 - heightGradient) * anisoBackFactor * (1.0 - rainStrength));
//	     color *= mix(1.0, 0.3, timeNight);
	
	
//	directColor  = sunlightColor * 40.0;
//	directColor *= 1.0 + pow(sunglow, 10.0) * 10.0 / (sunlight * 0.8 + 0.2);
//	directColor *= mix(vec3(1.0), vec3(0.4, 0.5, 0.6), timeNight);
	
//	ambientColor = mix(skylightColor, directColor, 0.15);
	
//	cloud.rgb = mix(ambientColor, directColor, sunlight);
	
	
	directLightFalloff  = pow5((worldPosition.y - cloudLowerHeight) / (cloudDepth - 25.0)) + sunglow * 0.005;
	directLightFalloff *= 1.0 + sunglow * 5.0 + pow(sunglow, 0.25);
	
	directColor  = sunlightColor * 50.0;
	directColor *= (1.0 + pow2(sunglow) * 2.0) * mix(1.0, 0.2, timeNight) * mix(1.0, 0.2, rainStrength);
	
	ambientColor  = mix(skylightColor, sunlightColor, 0.5);
	ambientColor *= 1.0;// * mix(1.0, 0.3, timeNight);
	
	bouncedColor = vec3(pow8(1.0 - heightGradient) * (anisoBackFactor + 0.5) * (1.0 - rainStrength));
	
	cloud.rgb  = mix(ambientColor, directColor, directLightFalloff);
//	cloud.rgb += bouncedColor;
	
	return cloud;
}

vec3 Get3DNoise3D(vec3 pos) {
	float p = floor(pos.z);
	float f = pos.z - p;
	
	float zStretch = 17.0;
	
	vec2 coord = pos.xy + p * zStretch;
	
	coord *= noiseResInverse;
	
	vec3 xy1 = texture2D(noisetex, coord).xyz;
	vec3 xy2 = texture2D(noisetex, coord + noiseResInverse * zStretch).xyz;
	
	return mix(xy1, xy2, f);
}

float GetCoverage(float clouds, float coverage) {
	return cubesmooth(clamp01((coverage + clouds - 1.0) * 1.1 - 0.1));
}

float CloudFBM(vec3 coord, out mat4x3 c, cvec3 weights, cfloat weight) {
	float time = CLOUD_SPEED_2D * TIME * 0.01;
	
	c[0]    = coord * 0.007;
	c[0]   += Get3DNoise3D(c[0]) * 0.3 - 0.15;
	c[0].x  = c[0].x * 0.25 + time;
	
	float cloud = -Get3DNoise(c[0]);
	
	c[1]    = c[0] * 2.0 - cloud * vec3(0.5, 1.0, 1.35);
	c[1].x += time;
	
	cloud += Get3DNoise(c[1]) * weights.x;
	
	c[2]  = c[1] * vec3(9.0, 3.0, 1.65) + time * vec3(3.0, 1.0, 0.55) - cloud * vec3(1.5, 1.0, 0.75);
	
	cloud += Get3DNoise(c[2]) * weights.y;
	
	c[3]   = c[2] * 3.0 + time;
	
	cloud += Get3DNoise(c[3]) * weights.z;
	
	cloud  = weight - cloud;
	
	cloud += Get3DNoise(c[3] * 3.0 + time) * 0.022;
	cloud += Get3DNoise(c[3] * 9.0 + time * 3.0) * 0.014;
	
	return cloud * 0.63;
}

vec4 CloudColor4(vec3 worldPosition, float coverage, vec2 coord, float sunglow) {
	cfloat density = 0.0;
	coverage *= 1.3;
//	coverage = CLOUD_COVERAGE_2D * 1.16 * 1.2;
	cvec3  weights  = vec3(0.5, 0.135, 0.075);
	cfloat weight   = weights.x + weights.y + weights.z;
	
	vec4 cloud;
	
	mat4x3 coords;
	
	cloud.a = CloudFBM(worldPosition, coords, weights, weight);
	cloud.a = GetCoverage(cloud.a, density, coverage);
	
	vec3 lightOffset = worldLightVector * 0.2;
	
	float sunlight;
	sunlight  = -Get3DNoise(coords[0] + lightOffset)            ;
	sunlight +=  Get3DNoise(coords[1] + lightOffset) * weights.x;
	sunlight +=  Get3DNoise(coords[2] + lightOffset) * weights.y;
	sunlight +=  Get3DNoise(coords[3] + lightOffset) * weights.z;
	sunlight  = GetCoverage(weight - sunlight, density, coverage);
	sunlight  = pow(1.3 - sunlight, 5.5);
	sunlight *= mix(pow(cloud.a, 1.6) * 2.5, 2.0, sunglow);
	sunlight *= mix(10.0, 1.0, sqrt(sunglow));
	
	vec3 directColor  = sunlightColor * 2.0;
	     directColor *= 1.0 + pow(sunglow, 10.0) * 10.0 / (sunlight * 0.8 + 0.2);
	     directColor *= mix(vec3(1.0), vec3(0.4, 0.5, 0.6), timeNight);
	
	vec3 ambientColor = mix(skylightColor, directColor, 0.15) * 0.1;
	
	cloud.rgb = mix(ambientColor, directColor, sunlight) * 70.0;
	
	return cloud;
}

void swap(io vec3 a, io vec3 b) {
	vec3 swap = a;
	a = b;
	b = swap;
}

void SetupCloudFBM() {
	float t = TIME * VOLUMETRIC_CLOUD_SPEED * 0.0095 * 8.0;
	
	cloudMul[0] = vec3(0.5, 0.5, 0.1);
	cloudAdd[0] = vec3(t * 1.0, 0.0, 0.0);
	
	cloudMul[1] = vec3(1.0, 2.0, 1.0);
	cloudAdd[1] = vec3(t * 0.577, 0.0, 0.0);
	
	cloudMul[2] = vec3(6.0, 6.0, 6.0);
	cloudAdd[2] = vec3(t * 5.272, 0.0, t * 0.905);
	
	cloudMul[3] = vec3(18.0);
	cloudAdd[3] = vec3(t * 19.721, 0.0, t * 6.62);
}

vec4 CalculateClouds3(io vec3 color, mat2x3 position, float depth) {
#ifndef VOLUMETRIC_CLOUDS
	return vec4(0.0);
#endif
	
//	if (depth < 1.0) return vec4(0.0);
	const ivec2[4] offsets = ivec2[4](ivec2(2), ivec2(-2, 2), ivec2(2, -2), ivec2(-2));
//	if (all(lessThan(textureGatherOffsets(depthtex1, texcoord, offsets, 0), vec4(1.0)))) return vec4(0.0);
	
	float i = 0;
	
	vec4 cloudSum = vec4(color, 0.0);
	
	float sunglow = CalculateSunglow(normalize(position[1]));
	
	vec3 a, b, rayPosition, rayIncrement;
	
	float samples = VolCloudSamples;
	
	a = position[1] * ((cloudUpperHeight - cameraPosition.y) / position[1].y);
	b = position[1] * ((cloudLowerHeight - cameraPosition.y) / position[1].y);
	
	if (cameraPosition.y < cloudLowerHeight) {
		if (position[1].y <= 0.0) return vec4(0.0);
		
		swap(a, b);
	} else if (cloudLowerHeight <= cameraPosition.y && cameraPosition.y <= cloudUpperHeight) {
		if (position[1].y < 0.0) {
			swap(a, b);
		}
		
		samples *= abs(a.y) / cloudDepth;
		b = vec3(0.0);
		swap(a, b);
	} else {
		if (position[1].y >= 0.0) return vec4(0.0);
	}
	
	samples = floor(samples);
	
	rayIncrement = (b - a) / (samples + 1.0);
	rayPosition = a + cameraPosition + rayIncrement * (1.0 + CalculateDitherPattern1());
	
	SetupCloudFBM();
	
	vec3 directColor  = sunlightColor;
	     directColor *= 8.0 * (1.0 + pow4(sunglow) * 10.0) * (1.0 - rainStrength * 0.8);
	
	vec3 ambientColor  = mix(sqrt(skylightColor), sunlightColor, 0.15);
	     ambientColor *= 2.0 * mix(vec3(1.0), vec3(0.6, 0.8, 1.0), timeNight);
	
	vec3 bouncedColor = mix(skylightColor, sunlightColor, 0.5);
	
	float coverage = baseCoverage * clamp01(1.0 - length2((rayPosition.xz - cameraPosition.xz) / 10000.0)); 
	
	while (cloudSum.a < 1.0 && i++ < samples) {
		vec4 cloud = CloudColor3(rayPosition, coverage, sunglow / 1.2, directColor, ambientColor, bouncedColor);
	//	vec4 cloud = CloudColor4(rayPosition, coverage, rayPosition.xz, sunglow);
		
		cloudSum.rgb = mix(cloudSum.rgb, cloud.rgb, (1.0 - cloudSum.a) * cloud.a);
		cloudSum.a += cloud.a;
		
		rayPosition += rayIncrement;
	}
	
	cloudSum.a = clamp01(cloudSum.a);
	
	color.rgb = mix(color.rgb, cloudSum.rgb, cloudSum.a);

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
	
	vec3 color = vec3(0.0, 0.5, 1.0) * float(depth0 >= 1.0)*0;
	vec4 cloud = CalculateClouds3(color, backPos, depth1);
	
	
	gl_FragData[3] = vec4(sqrt(cloud.rgb / 50.0), cloud.a);
	
	if (depth1 - mask.hand >= 1.0) { exit(); return; }
	
	
	vec3 diffuse = GetDiffuse(texcoord);
	vec3 viewSpacePosition0 = CalculateViewSpacePosition(vec3(texcoord, depth0));
	
	
	vec3 composite  = CalculateShadedFragment(mask, torchLightmap, skyLightmap, GI, normal, smoothness, backPos);
	     composite *= pow(diffuse, vec3(2.8));
	     composite  = LightDesaturation(composite, vec2(torchLightmap, skyLightmap));
	
	if (mask.water > 0.5 || isEyeInWater == 1)
		composite = WaterFog(composite, waterNormal, viewSpacePosition0, backPos[0]);
	
	composite += AerialPerspective(length(backPos[0]), skyLightmap) * (1.0 - mask.water);
	
	gl_FragData[0] = vec4(max0(composite), 1.0);
	
	exit();
}
