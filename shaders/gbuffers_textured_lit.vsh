#version 120

varying vec4	color;
varying vec2	texcoord;
varying vec2	lightCoord;

void main() {
	color					= gl_Color;
	texcoord			= gl_MultiTexCoord0.st;
	lightCoord		= (gl_TextureMatrix[1] * gl_MultiTexCoord1).st;

	gl_Position		= ftransform();
}
