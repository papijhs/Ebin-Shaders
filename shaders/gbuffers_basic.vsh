#version 120

varying vec3	color;

void main() {
	color = gl_Color.rgb;
	
	gl_Position	= ftransform();
}