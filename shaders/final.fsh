#version 120

const bool colortex2MipmapEnabled = true;

uniform sampler2D colortex2;
uniform sampler2D gdepthtex;

varying vec2 texcoord;

float GetDepth(in vec2 coord) {
	return texture2D(gdepthtex, coord).x;
}

vec3 GetColorDOF(in float depth) {
	float focusDepth = texture2D(gdepthtex, vec2(0.5)).x;
	
	float factor = min(abs(max(-0.1, (depth - focusDepth))) * 25.0, 2.0);
	
	return texture2DLod(colortex2, texcoord, factor).rgb;
}

void main() {
	float depth = GetDepth(texcoord);
	vec3  color = GetColorDOF(depth);
	
	gl_FragColor = vec4(color, 1.0);
}