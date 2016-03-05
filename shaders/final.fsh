#version 120

#define GAMMA 2.2

const bool colortex2MipmapEnabled		= true;

uniform sampler2D colortex3;
uniform sampler2D colortex2;
uniform sampler2D gdepthtex;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

uniform vec3 cameraPosition;

uniform float near;
uniform float far;

varying vec2 texcoord;

float GetMaterialIDs(in vec2 coord) {		//Function that retrieves the texture that has all material IDs stored in it
	return texture2D(colortex3, coord).b;
}

void ExpandMaterialIDs(inout float matID, inout float bit0, inout float bit1, inout float bit2, inout float bit3) {
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

float GetDepth(in vec2 coord) {
	return texture2D(gdepthtex, coord).x;
}

float DepthMapToViewDepth(in float depth) {
	return (near * far) / (near * depth + far * (1.0 - depth));
}

vec4 GetViewSpacePosition(in vec2 coord, in float depth) {
	vec4
	position = gbufferProjectionInverse * vec4(vec3(coord, depth) * 2.0 - 1.0, 1.0);
	position /= position.w;
	
	return position;
}

vec3 Tonemap(in vec3 color) {
	return pow(color / (color + vec3(0.6)), vec3(1.0 / 2.2));
}

struct Mask {
	float materialIDs;
	float matIDs;
	
	float bit0;
	float bit1;
	float bit2;
	float bit3;
	
	float sky;
} mask;

void CalculateMasks(inout Mask mask) {
	mask.materialIDs	= GetMaterialIDs(texcoord);
	mask.matIDs			= mask.materialIDs;
	
	ExpandMaterialIDs(mask.matIDs, mask.bit0, mask.bit1, mask.bit2, mask.bit3);
	
	mask.sky			= GetMaterialMask(255, mask.matIDs);
}

vec3 GetColorDOF(in float depth, in Mask mask) {
	float focusDepth = texture2D(gdepthtex, vec2(0.5)).x;
	
	float factor = abs(max(-0.1, (depth - focusDepth))) * 25.0;
	
	return texture2DLod(colortex2, texcoord, factor).rgb;
}

void main() {
	CalculateMasks(mask);
	
	float	depth	= GetDepth(texcoord);
	vec3	color	= GetColorDOF(depth, mask);
	
	gl_FragData[0] = vec4(color, 1.0);
}