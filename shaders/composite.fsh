#version 120

/* DRAWBUFFERS:4 */

#define SHADOW_MAP_BIAS 0.8    // [0.0 0.6 0.7 0.8 0.85 0.9]
#define EXTENDED_SHADOW_DISTANCE
#define GI_TRANSLUCENCE 0.2    // [0.0 0.2 0.4 0.6 0.8 1.0]

const bool shadowtex1Mipmap   = true;
const bool shadowcolor0Mipmap = true;
const bool shadowcolor1Mipmap = true;

uniform sampler2D colortex0;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler2D gdepthtex;
uniform sampler2D noisetex;
uniform sampler2D shadowcolor;
uniform sampler2D shadowcolor1;
uniform sampler2D shadowtex1;
uniform sampler2DShadow shadow;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;
uniform mat4 shadowModelViewInverse;

uniform vec3 cameraPosition;

uniform float frameTimeCounter;
uniform float sunAngle;

varying vec2 texcoord;

#include "/lib/PostHeader.fsh"
#include "/lib/GlobalCompositeVariables.fsh"
#include "/lib/Masks.glsl"


vec3 EncodeColor(in vec3 color) {    // Prepares the color to be sent through a limited dynamic range pipeline
	return pow(color * 0.001, vec3(1.0 / 2.2));
}

vec3 GetDiffuseLinear(in vec2 coord) {
	#ifndef DEFERRED_SHADING
	return pow(texture2D(colortex4, coord).rgb, vec3(2.2));
	#endif
	
	return pow(texture2D(colortex2, coord).rgb, vec3(2.2));
}

vec3 DecodeNormal(vec2 encodedNormal) {
	encodedNormal = encodedNormal * 2.0 - 1.0;
    vec2 fenc = encodedNormal * 4.0 - 2.0;
	float f = dot(fenc, fenc);
	float g = sqrt(1.0 - f / 4.0);
	return vec3(fenc * g, 1.0 - f / 2.0);
}

vec3 GetNormal(in vec2 coord) {
	return DecodeNormal(texture2D(colortex0, coord).xy);
}

float GetDepth(in vec2 coord) {
	return texture2D(gdepthtex, coord).x;
}

vec4 CalculateViewSpacePosition(in vec2 coord, in float depth) {
	vec4 position  = gbufferProjectionInverse * vec4(vec3(coord, depth) * 2.0 - 1.0, 1.0);
	     position /= position.w;
	
	return position;
}

vec4 ViewSpaceToWorldSpace(in vec4 viewSpacePosition) {
	return gbufferModelViewInverse * viewSpacePosition;
}

vec4 WorldSpaceToShadowSpace(in vec4 worldSpacePosition) {
	return shadowProjection * shadowModelView * worldSpacePosition;
}

float GetShadowBias(in vec2 shadowProjection) {
	#ifdef EXTENDED_SHADOW_DISTANCE
		shadowProjection *= 1.165;
		shadowProjection *= shadowProjection;
		shadowProjection *= shadowProjection;
		shadowProjection *= shadowProjection;
		
		return sqrt(sqrt(sqrt(shadowProjection.x + shadowProjection.y))) * SHADOW_MAP_BIAS + (1.0 - SHADOW_MAP_BIAS);
	#else
		return length(shadowProjection) * SHADOW_MAP_BIAS + (1.0 - SHADOW_MAP_BIAS);
	#endif
}

vec2 BiasShadowMap(in vec2 position, out float biasCoeff) {
	position = position * 2.0 - 1.0;
	
	biasCoeff = GetShadowBias(position);
	
	position /= biasCoeff;
	
	position = position * 0.5 + 0.5;
	
	return position;
}

vec2 Get2DNoise(in vec2 coord) {
	coord *= noiseTextureResolution;
	return texture2D(noisetex, coord).xy;
}

#define PI 3.14159

vec3 ComputeGlobalIllumination(in vec4 position, in vec3 normal, const in float radius, const in float quality, in vec2 noise) {
	position = WorldSpaceToShadowSpace(ViewSpaceToWorldSpace(position)) * 0.5 + 0.5;    //Convert the view-space position to shadow-map coordinates (unbiased)
	normal   = (shadowModelView * gbufferModelViewInverse * vec4(normal, 0.0)).xyz;    //Convert the normal from view-space to shadow-view-space
	
	float biasCoeff = GetShadowBias(position.xy);
	
	vec3 GI = vec3(0.0);
	
	const float interval    = 1.0 / quality;
	const float scale       = radius / shadowMapResolution;
	const float sampleCount = pow(1.0 / interval * 2.0 + 1.0, 2.0);
	
	
	for(float x = -1.0; x <= 1.0; x += interval) {
		for(float y = -1.0; y <= 1.0; y += interval) {
			vec2 polar = vec2(x, y) + noise;
			
			vec2 offset  = vec2(cos(PI * polar.y), sin(PI * polar.y)) * polar.x;
			     offset *= scale / biasCoeff;
			
			vec3 samplePos = vec3(position.xy + offset, 0.0);
			
			float sampleBiasCoeff;
			vec2 mapPos = BiasShadowMap(samplePos.xy, sampleBiasCoeff);
			
			float sampleLod = 5.0 * (1.0 - sampleBiasCoeff);
			
			samplePos.z = texture2DLod(shadowtex1, mapPos, sampleLod).x;
			samplePos.z = ((samplePos.z * 2.0 - 1.0) * 4.0) * 0.5 + 0.5;
			
			vec3 sampleDiff = position.xyz - samplePos.xyz;
			
			float distanceCoeff  = length(sampleDiff) * radius * 4.0;
			      distanceCoeff *= distanceCoeff;
			      distanceCoeff  = clamp(1.0 / distanceCoeff, 0.0, 1.0);
			
			float sampleRadiusCoeff = abs(polar.x);
			
			vec3 sampleDir    = normalize(sampleDiff);
			vec3 shadowNormal = texture2DLod(shadowcolor1, mapPos, sampleLod).xyz * 2.0 - 1.0;
			
			float viewNormalCoeff   = max(0.0, dot(      normal, sampleDir * vec3(-1.0, -1.0,  1.0))) * (1.0 - GI_TRANSLUCENCE) + GI_TRANSLUCENCE;
			float shadowNormalCoeff = max(0.0, dot(shadowNormal, sampleDir * vec3( 1.0,  1.0, -1.0)));
			
			float sampleCoeff = viewNormalCoeff * shadowNormalCoeff * distanceCoeff * sampleRadiusCoeff;
			
			if (sampleCoeff < 0.001 * sampleCount) continue;
			
			vec3 flux = pow(1.0 - texture2DLod(shadowcolor, mapPos, sampleLod).rgb, vec3(2.2));
			
			GI += flux * sampleCoeff;
		}
	}
	
	GI /= sampleCount;
	
	return GI * 5.0 * radius;
}


void main() {
	Mask mask;
	CalculateMasks(mask, texture2D(colortex3, texcoord).b, true);
	if (mask.sky > 0.5) { gl_FragData[0] = vec4(0.0, 0.0, 0.0, 1.0); return; }
	
	vec3  diffuse           = GetDiffuseLinear(texcoord);
	vec3  normal            = GetNormal(texcoord);
	float depth             = texture2D(gdepthtex, texcoord).x;
	
	float skyLightmap       = texture2D(colortex3, texcoord).g;
	vec4  viewSpacePosition = CalculateViewSpacePosition(texcoord, depth);
	vec2  noise2D           = Get2DNoise(texcoord);
	
	vec3 GI = ComputeGlobalIllumination(viewSpacePosition, normal, 16.0, 4.0, noise2D);
	
	gl_FragData[0] = vec4(EncodeColor(GI * diffuse), 1.0);
}