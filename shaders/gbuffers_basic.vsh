#version 120

varying vec4	color;
varying vec2	texcoord;
varying vec2	lightCoord;

void main() {
	gl_Position		= ftransform();
}
