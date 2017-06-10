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

#define VOLUMETRIC_CLOUD_SPEED 2.0
#define Cloud3Height 300
#define Vol_Cloud_Coverage 0.48
#define CLOUD_DISPERSE 10.0
#define Volumetric_Cloud_Type

float  	CalculateDitherPattern1() {
	const int[16] ditherPattern = int[16] (0 , 8 , 2 , 10,
									 	   12, 4 , 14, 6 ,
									 	   3 , 11, 1,  9 ,
									 	   15, 7 , 13, 5 );

	vec2 count = vec2(0.0);
	     count.x = floor(mod(texcoord.s * viewWidth, 4.0));
		 count.y = floor(mod(texcoord.t * viewHeight, 4.0));

	int dither = ditherPattern[int(count.x) + int(count.y) * 4];

	return float(dither) / 16.0;
}

vec3 GetCloudSpacePosition(vec2 coord, float linDepth, float distanceMult) {
	float expDepth = (far * (linDepth - near)) / (linDepth * (far - near));
	
	//Convert texture coordinates and depth into view space
	vec4 viewPos  = gbufferProjectionInverse * vec4(vec3(coord, expDepth) * 2.0 - 1.0, 1.0);
	     viewPos /= viewPos.w;
	
	//Convert from view space to world space
	vec3 worldPos = mat3(gbufferModelViewInverse) * viewPos.xyz;
	
	worldPos = worldPos * distanceMult + cameraPosition;
	
	return worldPos;
}

float CalculateSunglow2(vec3 vPos) {
	vec3 npos = normalize(vPos);
	vec3 halfVector2 = normalize(-lightVector + npos);
	float factor = 1.0 - dot(halfVector2, npos);
	
	return factor * factor * factor * factor;
}

float Get3DNoise(vec3 pos) {
	pos = pos.xzy;
	
	vec3 p = floor(pos);
	vec3 f = pos - p;

	vec2 coord  = f.xy + p.xy +  p.z * 17.0;
	vec2 coord2 = f.xy + p.xy + (p.z + 1.0) * 17.0;
	
	coord  *= noiseResInverse;
	coord2 *= noiseResInverse;
	
	float xy1 = texture2D(noisetex, coord ).x;
	float xy2 = texture2D(noisetex, coord2).x;
	
	return mix(xy1, xy2, f.z);
}

float Get3DNoise3(vec3 pos) {
	pos = pos.xzy;
	
	vec3 p = floor(pos);
	vec3 f = cubesmooth(pos - p);
	
	vec2 coord  = f.xy + p.xy +  p.z * 17.0;
	vec2 coord2 = f.xy + p.xy + (p.z + 1.0) * 17.0;
	
	coord  *= noiseResInverse;
	coord2 *= noiseResInverse;
	
	float xy1 = texture2D(noisetex, coord ).x;
	float xy2 = texture2D(noisetex, coord2).x;
	
	return mix(xy1, xy2, f.z);
}

float GetCoverage2(in float coverage, in float density, in float clouds) {
	clouds = clamp(clouds - (1.0 - coverage), 0.0, 1.0 -density) / (1.0 - density);
	clouds = max0(clouds * 1.1 - 0.1);
	clouds = cubesmooth(clouds);
	 
	return clouds;
}

vec4 CloudColor3(vec3 worldPosition, float sunglow, float cloudDepth) {
	
	float cloudUpperHeight = Cloud3Height + (cloudDepth / 2.0);
	float cloudLowerHeight = Cloud3Height - (cloudDepth / 2.0);
	
	if (worldPosition.y < cloudLowerHeight || worldPosition.y > cloudUpperHeight)
		return vec4(0.0);
	
	
	vec3 p = worldPosition.xyz / 150.0;
	
	float t = TIME * VOLUMETRIC_CLOUD_SPEED;
#ifdef Volumetric_Cloud_Type	 
	p.x -= t * 0.02;
	
	vec3 p1 = p * vec3(1.0, 0.5, 1.0)  + vec3(0.0, t * 0.01, 0.0);
	float noise  = 			   Get3DNoise(p) 				 * 1.0;	p *= 4.0;	p.x += t * 0.02; vec3 p2 = p;
	      noise += (1.0 - abs(Get3DNoise(p) * 3.0 - 1.0)) * 0.20;	p *= 3.0;	p.xz += t * 0.05;
	      noise += (1.0 - abs(Get3DNoise(p) * 3.0 - 1.5)-0.2) * 0.065;	p.xz -=t * 0.165;	p.xz += t * 0.05;
	      noise += (1.0 - abs(Get3DNoise(p) * 3.0 - 1.0)) * 0.05;	p *= 2.0;
	      noise += (1.0 - abs(Get3DNoise3(p) * 2.0 - 1.0)) * 0.015;
	      noise /= 1.2;
#else
	t *= 0.0095;
	
	p.x *= 0.5;
	p.x -= t * 0.01;
	
	vec3 p1 = p * vec3(1.0, 0.5, 1.0)  + vec3(0.0, t * 0.01, 0.0);
	
	float noise  = 	Get3DNoise(p * vec3(1.0, 0.5, 1.0) + vec3(0.0, t * 0.01, 0.0)) * 1.3;		p *= 2.0;	p.x -= t * 0.557;	vec3 p2 = p;
	      noise += (2.0 - abs(Get3DNoise(p) * 2.0 - 0.0)) * (0.35);								p *= 3.0;	p.xz -= t * 0.905;	p.x *= 2.0;	vec3 p3 = p; 	float largeNoise = noise;
	      noise += (3.0 - abs(Get3DNoise(p) * 3.0 - 0.0)) * (0.085);							p *= 3.0;	p.xz -= t * 3.905;	vec3 p4 = p;
	      noise += (3.0 - abs(Get3DNoise(p) * 3.0 - 0.0)) * (0.035);							p *= 3.0;	p.xz -= t * 3.905;
	      noise += ((Get3DNoise(p))) * (0.04);														p *= 3.0;
	      noise /= 2.375;
#endif	  
	
	const float lightOffset = 0.3;
	
	float heightGradient = clamp(( - (cloudLowerHeight - worldPosition.y) / (cloudDepth * 1.0)), 0.0, 1.0);
	float heightGradient2 = clamp(( - (cloudLowerHeight - (worldPosition.y + worldLightVector.y * lightOffset * 150.0)) / (cloudDepth * 1.0)), 0.0, 1.0);
	
	float cloudAltitudeWeight = 1.0 - clamp(distance(worldPosition.y, Cloud3Height) / (cloudDepth / 2.0), 0.0, 1.0);
	      cloudAltitudeWeight = (-cos(cloudAltitudeWeight * 3.1415)) * 0.5 + 0.5;
	      cloudAltitudeWeight = pow(cloudAltitudeWeight, mix(0.33, 0.8, rainStrength));
	
	float cloudAltitudeWeight2 = 1.0 - clamp(distance(worldPosition.y + worldLightVector.y * lightOffset * 150.0, Cloud3Height) / (cloudDepth / 2.0), 0.0, 1.0);
	      cloudAltitudeWeight2 = (-cos(cloudAltitudeWeight2 * 3.1415)) * 0.5 + 0.5;
	      cloudAltitudeWeight2 = pow(cloudAltitudeWeight2, mix(0.33, 0.8, rainStrength));
	
	noise *= cloudAltitudeWeight;
	
	//cloud edge
	float rainy = mix(wetness, 1.0, rainStrength);
	float coverage = Vol_Cloud_Coverage + rainy * 0.335;
	
	float dist = length(worldPosition.xz - cameraPosition.xz);
	coverage *= max(0.0, 1.0 - dist / 40000.0); 
	
	float density = 0.90;
	noise = GetCoverage2(coverage, density, noise);
	noise = pow(noise, 1.5);
	
	if (noise <= 0.001)
		return vec4(0.0);

	float sundiff  = Get3DNoise3(p1 + worldLightVector * lightOffset);
	      sundiff += (1.0 - abs(Get3DNoise3(p2 + worldLightVector * lightOffset / 2.0) * 1.0 - 0.5) - 0.1) * 0.55;
	      sundiff *= 0.955;
	      sundiff *= cloudAltitudeWeight2;
	float preCoverage = sundiff;
	      sundiff  = -GetCoverage2(coverage * 1.0, density * 0.5, sundiff);
	
	float sundiff2    = -GetCoverage2(coverage * 1.0, 0.0, preCoverage);
	float firstOrder  = pow(clamp(sundiff * 1.2 + 1.7, 0.0, 1.0), 8.0);
	float secondOrder = pow(clamp(sundiff2 * 1.2 + 1.1, 0.0, 1.0), 4.0);
	
	float anisoBackFactor = mix(clamp(pow(noise, 1.6) * 2.5, 0.0, 1.0), 1.0, pow(sunglow, 1.0));
	      firstOrder  *= anisoBackFactor * 0.99 + 0.01;
	      secondOrder *= anisoBackFactor * 1.19 + 0.9;
	
	float directLightFalloff = clamp(pow(-(cloudLowerHeight - worldPosition.y) / cloudDepth, 3.5), 0.0, 1.0);
	      directLightFalloff *= mix(	clamp(pow(noise, 0.9), 0.0, 1.0), 	clamp(pow(1.0 - noise, 10.3), 0.0, 0.5), 	pow(sunglow, 0.2));
	
	vec3 colorDirect  = sunlightColor * 12.5;
	     colorDirect  = mix(colorDirect, colorDirect * vec3(0.1, 0.2, 0.3), timeNight);
	     colorDirect  = mix(colorDirect, colorDirect * vec3(0.2, 0.2, 0.2), rainStrength);
	     colorDirect *= 1.0 + pow(sunglow, 4.0) * 100.0;
	
	vec3 colorAmbient  = mix(skylightColor, sunlightColor, 0.15) * 0.065;
	     colorAmbient *= mix(1.0, 0.3, timeNight);
	
	vec3 colorBounced  = vec3(1.0) * 0.35;
	     colorBounced *= pow((1.0 - heightGradient), 8.0);
	     colorBounced *= anisoBackFactor + 0.5;
	     colorBounced *= 1.0 - rainStrength;
	
	vec3 color  = mix(colorAmbient, colorDirect, vec3(directLightFalloff));
	     color += colorBounced;
	
	return vec4(color.rgb, noise);
}

vec4 CalculateClouds3(io vec3 color, mat2x3 position, float skyMask) {
//	show(all(lessThan(textureGather(gdepthtex, texcoord, 0), vec4(1.0))))
	
	if (skyMask < 0.5) return vec4(0.0);
	
	float rayDepth = far - 5.0;
	
//	float rayIncrement = far / CLOUD_DISPERSE;
//	rayDepth += CalculateDitherPattern1() * rayIncrement;
	
	int i = 0;
	
	vec4 cloudSum = vec4(color, 0.0);
	
	float sunglow = min(CalculateSunglow2(position[0]), 2.0);
	
	float cloudDistanceMult = 400.0 / far;
	
	float cloudDepth = 150.0;
	
	float cloudUpperHeight = Cloud3Height + (cloudDepth / 2.0);
	float cloudLowerHeight = Cloud3Height - (cloudDepth / 2.0);
	
	vec3 a, b, rayPosition, rayIncrement;
	
	int samples = 10;
	
	if (cameraPosition.y < cloudLowerHeight) {
		if (position[1].y <= 0.0) return vec4(0.0);
		
		a = position[1] * ((cloudUpperHeight - cameraPosition.y) / position[1].y);
		b = position[1] * ((cloudLowerHeight - cameraPosition.y) / position[1].y);
		
		rayPosition = a + cameraPosition;
		rayIncrement = (b - a) * (CalculateDitherPattern1() / samples);
	} else if (cloudLowerHeight <= cameraPosition.y && cameraPosition.y <= cloudUpperHeight) {
		a = position[1] * ((cloudUpperHeight - cameraPosition.y) / position[1].y);
		b = position[1] * ((cloudLowerHeight - cameraPosition.y) / position[1].y);
		
		float c = float(samples);
		
		if (position[1].y < 0.0) {
			a = vec3(0.0);
			c *= abs(cloudLowerHeight - cameraPosition.y) / abs(cloudUpperHeight - cloudLowerHeight);
			rayPosition = b + cameraPosition;
			rayIncrement = (a - b) * (CalculateDitherPattern1() / c);
			samples = int(c);
		} else {
			b = vec3(0.0);
			c *= abs(cloudUpperHeight - cameraPosition.y) / abs(cloudUpperHeight - cloudLowerHeight);
			rayPosition = a + cameraPosition;
			rayIncrement = (b - a) * (CalculateDitherPattern1() / c);
			samples = int(c);
		}
	} else {
		if (position[1].y >= 0.0) return vec4(0.0);
		
		a = position[1] * ((cloudUpperHeight - cameraPosition.y) / position[1].y);
		b = position[1] * ((cloudLowerHeight - cameraPosition.y) / position[1].y);
		
		rayPosition = b + cameraPosition;
		rayIncrement = (a - b) * (CalculateDitherPattern1() / samples);
	}
	
//	while (rayDepth > 0.0 && i < 50) {
	while ( i < samples) {
	//	vec3 rayPosition = GetCloudSpacePosition(texcoord, rayDepth, cloudDistanceMult);
		
		vec4 proximity = CloudColor3(rayPosition, sunglow / 1.2, cloudDepth);
		
		cloudSum.rgb = mix(cloudSum.rgb, proximity.rgb, proximity.a);
		cloudSum.a += proximity.a;
		
		rayPosition += rayIncrement;
	//	rayDepth -= rayIncrement;
		i++;
	}
	
	color.rgb = mix(color.rgb, cloudSum.rgb, clamp01(cloudSum.a * 50.0));
	
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
	
	vec3 color = vec3(0.0, 0.5, 1.0) * float(depth0 >= 1.0);
	vec4 cloud = CalculateClouds3(color, backPos, float(depth1 >= 1.0));
	show(color);
	
//	gl_FragData[3] = vec4(cloud);
	
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
