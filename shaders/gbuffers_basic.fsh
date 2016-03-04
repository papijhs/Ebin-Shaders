#version 450 compatibility

uniform sampler2D		texture;
uniform sampler2D		lightmap;

varying vec4	color;
varying vec2	texcoord;
varying vec2	lightCoord;

void main() {
	discard;
}
