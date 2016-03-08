#version 120

/* DRAWBUFFERS:2 */

#include "include/PostHeader.fsh"

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

uniform float sunAngle;
uniform float far;

varying vec3 lightVector;
varying vec2 texcoord;
varying vec3 colorSkylight;


struct Mask {
	float materialIDs;
	float matIDs;
	
	float bit0;
	float bit1;
	float bit2;
	float bit3;
	
	float grass;
	float leaves;
	float sky;
};


float GetMaterialIDs(in vec2 coord) {    //Function that retrieves the texture that has all material IDs stored in it
	return texture2D(colortex3, coord).b;
}

vec3 GetColor(in vec2 coord) {
	return texture2D(colortex2, coord).rgb;
}

vec3 DecodeColor(in vec3 color) {
	return pow(color, vec3(2.2)) * 1000.0;
}

vec3 EncodeColor(in vec3 color) {    //Prepares the color to be sent through a limited dynamic range pipeline
	return pow(color * 0.001, vec3(1.0 / 2.2));
}

float GetDepth(in vec2 coord) {
	return texture2D(gdepthtex, coord).x;
}

vec4 GetViewSpacePosition(in vec2 coord, in float depth) {
	vec4 position  = gbufferProjectionInverse * vec4(vec3(coord, depth) * 2.0 - 1.0, 1.0);
	     position /= position.w;
	
	return position;
}


void DecodeMaterialIDs(inout float matID, inout float bit0, inout float bit1, inout float bit2, inout float bit3) {
	matID *= 255.0;
	
	if (matID >= 128.0 && matID < 254.5) {
		matID -= 128.0;
		bit0 = 1.0;
	}
	
	if (matID >= 64.0 && matID < 254.5) {
		matID -= 64.0;
		bit1 = 1.0;
	}
	
	if (matID >= 32.0 && matID < 254.5) {
		matID -= 32.0;
		bit2 = 1.0;
	}
	
	if (matID >= 16.0 && matID < 254.5) {
		matID -= 16.0;
		bit3 = 1.0;
	}
}

float GetMaterialMask(in float mask, in float materialID) {
	return float(abs(materialID - mask) < 0.1);
}

void CalculateMasks(inout Mask mask, in float materialIDs, const bool encoded) {
	mask.materialIDs = materialIDs;
	mask.matIDs      = mask.materialIDs;
	
	if (encoded) DecodeMaterialIDs(mask.matIDs, mask.bit0, mask.bit1, mask.bit2, mask.bit3);
	
	mask.grass  = GetMaterialMask(2, mask.matIDs);
	mask.leaves = GetMaterialMask(3, mask.matIDs);
	mask.sky    = GetMaterialMask(255, mask.matIDs);
}


float CalculateFogFactor(in vec4 position, in float power) {
	float fogFactor = length(position.xyz);
		  fogFactor = max(fogFactor - gl_Fog.start, 0.0);
		  fogFactor /= far - gl_Fog.start;
		  fogFactor = pow(fogFactor, power);
		  fogFactor = clamp(fogFactor, 0.0, 1.0);
	
	return fogFactor;
}

vec3 CalculateSkyGradient(in vec4 viewSpacePosition) {
	vec3 color = vec3(0.0);
	
	float radius = far;
	const float horizonLevel = 70.0;
	
	vec3 worldPosition = normalize((gbufferModelViewInverse * viewSpacePosition).xyz) * radius;
	     vec3 oldPos = worldPosition.xyz;
	     worldPosition.xz = normalize(worldPosition.xz) * radius;
	     worldPosition.y = (length(worldPosition.xz) / length(oldPos.xz)) * oldPos.y + cameraPosition.y - horizonLevel;
	
	float horizon = dot(vec3(0.0, 1.0, 0.0), normalize(worldPosition));
	      if (horizon < 0.0) horizon = clamp( -horizon * 0.5 , 0.0, 1.0);
		  horizon = pow(1.0 - pow(horizon, 1.5), 20.0);
	
	return (horizon + 0.3) * colorSkylight * 2.0;
}

vec4 CalculateSky(in vec3 diffuse, in vec4 viewSpacePosition, in Mask mask) {
	float fogFactor = max(CalculateFogFactor(viewSpacePosition, 2.0), mask.sky);
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
	float depth             = GetDepth(texcoord);
	vec4  viewSpacePosition = GetViewSpacePosition(texcoord, depth);
	
	vec4 sky = CalculateSky(color, viewSpacePosition, mask);
	
	color = DecodeColor(color);
	
	color = mix(color, sky.rgb, sky.a);
	
	gl_FragData[0] = vec4(EncodeColor(color), 1.0);
}