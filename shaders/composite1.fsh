#version 120

/* DRAWBUFFERS:2 */

#define SHADOW_MAP_BIAS 0.8    //[0.0 0.6 0.7 0.8 0.85 0.9]
#define SOFT_SHADOWS
#define EXTENDED_SHADOW_DISTANCE

const bool colortex4MipmapEnabled = true;

uniform sampler2D colortex0;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler2D gdepthtex;
uniform sampler2D shadowcolor;
uniform sampler2DShadow shadow;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;
uniform mat4 shadowModelViewInverse;

uniform float viewWidth;
uniform float viewHeight;

varying vec2 texcoord;

#include "/lib/PostHeader.fsh"
#include "/lib/GlobalCompositeVariables.fsh"
#include "/lib/Masks.glsl"
#include "/lib/ShadingStructs.fsh"
#include "/lib/ShadingFunctions.fsh"


vec3 DecodeColor(in vec3 color) {
	return pow(color, vec3(2.2)) * 1000.0;
}

vec3 EncodeColor(in vec3 color) {    // Prepares the color to be sent through a limited dynamic range pipeline
	return pow(color * 0.001, vec3(1.0 / 2.2));
}

vec3 GetDiffuse(in vec2 coord) {
	return texture2D(colortex2, coord).rgb;
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

vec4 CalculateViewSpacePosition(in vec2 coord, in float depth) {
	vec4 position  = gbufferProjectionInverse * vec4(vec3(coord, depth) * 2.0 - 1.0, 1.0);
	     position /= position.w;
	
	return position;
}

vec3 GetIndirectLight(in vec2 coord) {
	return DecodeColor(texture2D(colortex4, coord).rgb);
}


void main() {
	Mask mask;
	CalculateMasks(mask, texture2D(colortex3, texcoord).b, true);
	
	if (mask.sky > 0.5) { gl_FragData[0] = vec4(texture2D(colortex2, texcoord).rgb, 1.0); return; }
	
	vec3  diffuse           = GetDiffuse(texcoord);
	vec3  normal            = GetNormal(texcoord);
	float depth             = texture2D(gdepthtex, texcoord).x;
	
	vec3 final = DecodeColor(diffuse);
	
	#ifdef DEFERRED_SHADING
	float torchLightmap     = texture2D(colortex3, texcoord).r;
	float skyLightmap       = texture2D(colortex3, texcoord).g;
	vec4  viewSpacePosition = CalculateViewSpacePosition(texcoord, depth);
	
	vec3 composite = CalculateShadedFragment(diffuse, mask, torchLightmap, skyLightmap, normal, viewSpacePosition);
	
	final = composite;
	#endif
	
	final += GetIndirectLight(texcoord);
	
	
	gl_FragData[0] = vec4(EncodeColor(final), 1.0);
}