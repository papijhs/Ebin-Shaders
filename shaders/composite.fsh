#version 120

/* DRAWBUFFERS:4 */

#define SHADOW_MAP_BIAS 0.8    //[0.0 0.6 0.7 0.8 0.85 0.9]
#define EXTENDED_SHADOW_DISTANCE

#include "/lib/PostHeader.fsh"
#include "/lib/GlobalCompositeVariables.fsh"

const bool 		shadowtex1Mipmap   = true;
const bool 		shadowcolor0Mipmap = true;
const bool 		shadowcolor1Mipmap = true;

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


#include "/lib/Masks.glsl"


float GetMaterialIDs(in vec2 coord) {    //Function that retrieves the texture that has all material IDs stored in it
	return texture2D(colortex3, coord).b;
}

vec3 GetDiffuse(in vec2 coord) {
	#ifndef DEFERRED_SHADING
	return texture2D(colortex4, coord).rgb;
	#endif
	
	return texture2D(colortex2, coord).rgb;
}

float GetSkyLightmap(in vec2 coord) {
	return texture2D(colortex3, coord).g;
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

vec4 GetViewSpacePosition(in vec2 coord, in float depth) {
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

vec2 BiasShadowMap(in vec2 position) {
	position = position * 2.0 - 1.0;
	
	#ifdef EXTENDED_SHADOW_DISTANCE
		vec2 pos = abs(position * 1.165);
		float biasCoeff = pow(pow(pos.x, 8) + pow(pos.y, 8), 1.0 / 8.0);
	#else
		float biasCoeff = length(position);
	#endif
	
	biasCoeff = biasCoeff * SHADOW_MAP_BIAS + (1.0 - SHADOW_MAP_BIAS);
	
	position /= biasCoeff;
	
	position = position * 0.5 + 0.5;
	
	return position;
}

vec2 Get2DNoise(in vec2 coord) {
	coord *= noiseTextureResolution;
//	coord += frameTimeCounter;
	return texture2D(noisetex, coord).xy;
}

#define PI 3.14159

vec3 ComputeGlobalIllumination(in vec4 position, in vec3 normal, const in float radius, const in float quality, in vec2 noise) {
	position = WorldSpaceToShadowSpace(ViewSpaceToWorldSpace(position)) * 0.5 + 0.5;    //Convert the view-space position to shadow-map coordinates (unbiased)
	normal   = (shadowModelView * gbufferModelViewInverse * vec4(normal, 0.0)).xyz;    //Convert the normal from view-space to shadow-view-space
	
	vec3 GI = vec3(0.0);
	
	const float interval    = 1.0 / quality;
	const float scale       = radius / shadowMapResolution;
	const float sampleCount = pow(1.0 / interval * 2.0 + 1.0, 2.0);
	
	float sampleLod = 4.0;
	
	for(float x = -1.0; x <= 1.0; x += interval) {
		for(float y = -1.0; y <= 1.0; y += interval) {
			vec2 a = (vec2(x, y) + noise);
			vec2 offset    = vec2(cos(PI * a.y), sin(PI * a.y)) * a.x * scale * 4.0;
			vec3 samplePos = vec3(position.xy + offset, 0.0);
			vec2 mapPos    = BiasShadowMap(samplePos.xy);
			samplePos.z    = texture2DLod(shadowtex1, mapPos, sampleLod).x;
			#ifdef EXTENDED_SHADOW_DISTANCE
				samplePos.z = ((samplePos.z * 2.0 - 1.0) * 4.0) * 0.5 + 0.5;
			#endif
			
			vec3 sampleDiff = position.xyz - samplePos.xyz;
			
			float distanceCoeff  = length(sampleDiff) * radius;
			      distanceCoeff *= distanceCoeff;
			      distanceCoeff  = clamp(1.0 / distanceCoeff, 0.0, 1.0);
			
			vec3 shadowNormal = texture2DLod(shadowcolor1, mapPos, sampleLod).xyz * 2.0 - 1.0;
			vec3 sampleDir    = normalize(sampleDiff);
			
			float viewNormalCoeff   = max(0.0, dot(      normal, sampleDir * vec3(-1.0, -1.0,  1.0)) * 0.4 + 0.6);
			float shadowNormalCoeff = max(0.0, dot(shadowNormal, sampleDir * vec3( 1.0,  1.0, -1.0)));
			
			float sampleCoeff = viewNormalCoeff * shadowNormalCoeff * distanceCoeff * abs(x);
			
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
	CalculateMasks(mask, GetMaterialIDs(texcoord), true);
	
	if (mask.sky > 0.5) { gl_FragData[0] = vec4(texture2D(colortex2, texcoord).rgb, 1.0); return; }
	
	vec3  diffuse           = GetDiffuse(texcoord);
	float skyLightmap       = GetSkyLightmap(texcoord);
	vec3  normal            = GetNormal(texcoord);
	float depth             = GetDepth(texcoord);
	vec4  viewSpacePosition = GetViewSpacePosition(texcoord, depth);
	vec2  noise2D           = Get2DNoise(texcoord);
	
	vec3 GI = ComputeGlobalIllumination(viewSpacePosition, normal, 16.0, 4.0, noise2D);
	
	gl_FragData[0] = vec4(GI * pow(diffuse, vec3(2.2)), 1.0);
}