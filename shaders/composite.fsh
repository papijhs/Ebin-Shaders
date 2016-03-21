#version 120

/* DRAWBUFFERS:45 */

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
uniform float far;

varying vec2 texcoord;

#include "/lib/Settings.txt"
#include "/lib/PostHeader.fsh"
#include "/lib/GlobalCompositeVariables.fsh"
#include "/lib/Masks.glsl"
#include "/lib/CalculateFogFactor.glsl"


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
	return texture2D(noisetex, coord).xy * 2.0 - 1.0;
}

#define PI 3.14159

vec3 ComputeGlobalIllumination(in vec4 position, in vec3 normal, const in float radius, const in float quality, in vec2 noise) {
	position = WorldSpaceToShadowSpace(ViewSpaceToWorldSpace(position)) * 0.5 + 0.5;    //Convert the view-space position to shadow-map coordinates (unbiased)
	normal   = (shadowModelView * gbufferModelViewInverse * vec4(normal, 0.0)).xyz;    //Convert the normal from view-space to shadow-view-space
	
	float biasCoeff = GetShadowBias(position.xy);
	
	vec3 GI = vec3(0.0);
	
	const float brightness  = 2.0 * radius;
	const float interval    = 1.0 / quality;
	const float scale       = 2.7 * radius / shadowMapResolution;
	const float sampleCount = pow(1.0 / interval * 2.0 + 1.0, 2.0);
	
	
	for(float x = -1.0; x <= 1.0; x += interval) {
		for(float y = -1.0; y <= 1.0; y += interval) {
			vec2 polar = vec2(x, y) + noise;
			
			vec2 offset  = vec2(cos(PI * polar.y), sin(PI * polar.y)) * polar.x;
			     offset *= scale / biasCoeff;
			
			vec3 samplePos = vec3(position.xy + offset, 0.0);
			
			float sampleBiasCoeff;
			vec2 mapPos = BiasShadowMap(samplePos.xy, sampleBiasCoeff);
			
			float sampleLod = 3.0 * (1.0 - sampleBiasCoeff) + 2.0;
			
			samplePos.z = texture2DLod(shadowtex1, mapPos, sampleLod).x;
			samplePos.z = ((samplePos.z * 2.0 - 1.0) * 4.0) * 0.5 + 0.5;
			
			vec3 sampleDiff  = position.xyz - samplePos.xyz;
			
			float distanceCoeff  = length(sampleDiff) * radius  ;
			      distanceCoeff *= distanceCoeff;
			      distanceCoeff  = clamp(1.0 / distanceCoeff, 0.0, 1.0);
			
			float sampleRadiusCoeff = sqrt(abs(polar.x));
			
			vec3 sampleDir    = normalize(sampleDiff);
			vec3 shadowNormal = texture2DLod(shadowcolor1, mapPos, sampleLod).xyz * 2.0 - 1.0;
			
			float viewNormalCoeff   = max(0.0, dot(      normal, sampleDir * vec3(-1.0, -1.0,  1.0))) * (1.0 - GI_TRANSLUCENCE) + GI_TRANSLUCENCE;
			float shadowNormalCoeff = max(0.0, dot(shadowNormal, sampleDir * vec3( 1.0,  1.0, -1.0)));
			
			float sampleCoeff = sqrt(viewNormalCoeff * shadowNormalCoeff) * distanceCoeff * sampleRadiusCoeff;
			
			if (sampleCoeff < 0.001 * sampleCount / brightness) continue;
			
			vec3 flux = pow(1.0 - texture2DLod(shadowcolor, mapPos, sampleLod).rgb, vec3(2.2));
			
			GI += flux * sampleCoeff;
		}
	}
	
	GI /= sampleCount;
	
	return GI * brightness;
}

vec4 BiasShadowProjection(in vec4 position, out float biasCoeff) {
	#ifdef EXTENDED_SHADOW_DISTANCE
		vec2 pos = abs(position.xy * 1.165);
		biasCoeff = pow(pow(pos.x, 8) + pow(pos.y, 8), 1.0 / 8.0);
	#else
		biasCoeff = length(position.xy);
	#endif
	
	biasCoeff = biasCoeff * SHADOW_MAP_BIAS + (1.0 - SHADOW_MAP_BIAS);
	
	position.xy /= biasCoeff;
	position.z /= 4.0;
	
	return position;
}

float ComputeVolumetricLight(in vec4 viewSpacePosition, in float noise1D) {
	
	float fog = 0.0;
	float sampleCount = 0.0;
	float rayIncrement = 0.25;
	
	float biasCoeff;
	
	vec3 rayStep = normalize(viewSpacePosition.xyz + vec3(0.0, 0.0, noise1D));

	vec3 ray = rayStep * gl_Fog.start;
	
	while (length(ray) < length(viewSpacePosition.xyz)) {
		sampleCount++;
		
		ray += rayStep * rayIncrement;
		rayIncrement *= 1.01;
		
		vec3 samplePosition = BiasShadowProjection(WorldSpaceToShadowSpace(ViewSpaceToWorldSpace(vec4(ray, 1.0))), biasCoeff).xyz * 0.5 + 0.5;
		
		float sample = shadow2D(shadow, samplePosition).x * rayIncrement;
		
		float sampleFog = CalculateFogFactor(vec4(ray, 1.0), FOGPOW);
		
		fog += sqrt(sample * sampleFog);
	}
	
	return fog / sampleCount * 4.0;
}


void main() {
	Mask mask;
	CalculateMasks(mask, texture2D(colortex3, texcoord).b, true);
	
	if (mask.sky > 0.5) { gl_FragData[0] = vec4(0.0, 0.0, 0.0, 1.0); gl_FragData[1] = vec4(1.0, 0.0, 0.0, 1.0); return; }
	
	vec3  normal            = GetNormal(texcoord);
	float depth             = texture2D(gdepthtex, texcoord).x;
	vec4  viewSpacePosition = CalculateViewSpacePosition(texcoord, depth);
	
	vec2  noise2D           = Get2DNoise(texcoord);
	
	vec3  diffuse           = GetDiffuseLinear(texcoord);
	float skyLightmap       = texture2D(colortex3, texcoord).g;
	
	vec3 GI = ComputeGlobalIllumination(viewSpacePosition, normal, 16.0, 4.0, noise2D);
	
	float VL = ComputeVolumetricLight(viewSpacePosition, noise2D.x);
	
	gl_FragData[0] = vec4(EncodeColor(GI * diffuse), 1.0);
	gl_FragData[1] = vec4(VL, 0.0, 0.0, 1.0);
}