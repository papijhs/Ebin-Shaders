#version 150 compatibility

out vec3	color;
out vec2	texcoord;

void main() {
	color		= gl_Color.rgb;
	texcoord	= gl_MultiTexCoord0.st;
	
	gl_Position	= ftransform();
}