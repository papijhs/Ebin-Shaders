#version 120

/* DRAWBUFFERS:2 */

uniform sampler2D colortex0;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
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

uniform vec3 cameraPosition;
uniform vec3 upPosition;

uniform float far;

varying vec2 texcoord;

#include "/lib/Settings.txt"
#include "/lib/PostHeader.fsh"
#include "/lib/GlobalCompositeVariables.fsh"
#include "/lib/CalculateFogFactor.glsl"
#include "/lib/Masks.glsl"


float GetMaterialIDs(in vec2 coord) {    // Function that retrieves the texture that has all material IDs stored in it
	return texture2D(colortex3, coord).b;
}

vec3 DecodeColor(in vec3 color) {
	return pow(color, vec3(2.2)) * 1000.0;
}

vec3 EncodeColor(in vec3 color) {    // Prepares the color to be sent through a limited dynamic range pipeline
	return pow(color * 0.001, vec3(1.0 / 2.2));
}

vec3 GetColor(in vec2 coord) {
	return texture2D(colortex2, coord).rgb;
}

vec4 CalculateViewSpacePosition(in vec2 coord, in float depth) {
	vec4 position  = gbufferProjectionInverse * vec4(vec3(coord, depth) * 2.0 - 1.0, 1.0);
	     position /= position.w;
	
	return position;
}

vec3 CalculateSkyGradient(in vec4 viewSpacePosition) {
	float radius = max(176.0, far * sqrt(2.0));
	const float horizonLevel = 64.0;
	
	vec3 worldPosition = (gbufferModelViewInverse * vec4(normalize(viewSpacePosition.xyz), 0.0)).xyz;
	     worldPosition.y = radius * worldPosition.y / length(worldPosition.xz) + cameraPosition.y - horizonLevel;
	     worldPosition.xz = normalize(worldPosition.xz) * radius;
	
	float dotUP = dot(normalize(worldPosition), vec3(0.0, 1.0, 0.0));
	
	float horizonCoeff  = dotUP * 0.65;
	      horizonCoeff  = abs(horizonCoeff);
	      horizonCoeff  = pow(1.0 - horizonCoeff, 3.0) / 0.65 * 5.0 + 0.35;
	
	vec3 color = colorSkylight * horizonCoeff;
	
	return color;
}

vec4 CalculateSky(in vec3 diffuse, in vec4 viewSpacePosition, in Mask mask) {
	float fogFactor = max(CalculateFogFactor(viewSpacePosition, FOGPOW), mask.sky);
	vec3  gradient  = CalculateSkyGradient(viewSpacePosition);
	vec4  composite;
	
	
	composite.a   = fogFactor;
	composite.rgb = gradient;
	
	
	return vec4(composite);
}


void main() {
	Mask mask;
	CalculateMasks(mask, GetMaterialIDs(texcoord), true);
	
	vec3  color             = GetColor(texcoord);
	float depth             = texture2D(gdepthtex, texcoord).x;
	vec4  viewSpacePosition = CalculateViewSpacePosition(texcoord, depth);
	
	vec4 sky = CalculateSky(color, viewSpacePosition, mask);
	
	color = DecodeColor(color);
	
	color = mix(color, sky.rgb, sky.a);
	
	gl_FragData[0] = vec4(EncodeColor(color), 1.0);
}