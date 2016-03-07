#version 120

#include "include/PostHeader.fsh"

const bool colortex2MipmapEnabled = true;

uniform sampler2D colortex2;
uniform sampler2D gdepthtex;

varying vec2 texcoord;


float GetDepth(in vec2 coord) {
	return texture2D(gdepthtex, coord).x;
}

vec3 GetColor(in vec2 coord) {
	return pow(texture2D(colortex2, coord).rgb, vec3(2.2));
}

vec3 GetColorDOF(in float depth) {
	float focusDepth = texture2D(gdepthtex, vec2(0.5)).x;
	
	float factor = min(abs(max(-0.1, (depth - focusDepth))) * 25.0, 2.0);
	
	return texture2DLod(colortex2, texcoord, factor).rgb;
}

vec3 Tonemap(in vec3 color) {
	return pow(color / (color + vec3(0.6)), vec3(1.0 / 2.2));
}

vec3 Uncharted2Tonemap(in vec3 color) {
	const float A = 0.15, B = 0.5, C = 0.1, D = 0.2, E = 0.02, F = 0.3, W = 11.2;
	const float whiteScale = 1.0 / (((W * (A * W + C * B) + D * E) / (W * (A * W + B) + D * F)) - E / F);
	const float ExposureBias = 2300.0;
	
	vec3 curr = ExposureBias * color;
	     curr = ((curr * (A * curr + C * B) + D * E) / (curr * (A * curr + B) + D * F)) - E / F;
	
	color = curr * whiteScale;
	
	return pow(color, vec3(1.0 / 2.2));
}

void main() {
//	float depth = GetDepth(texcoord);
	vec3  color = GetColor(texcoord);
	      color = Uncharted2Tonemap(color);
	
	gl_FragColor = vec4(color, 1.0);
}