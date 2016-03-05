#version 120

/* DRAWBUFFERS:2 */

uniform sampler2D	texture;

varying vec3	color;
varying vec2	texcoord;

void main() {
	vec4 diffuse	= texture2D(texture, texcoord);
	diffuse.rgb		*= color;
	
	gl_FragData[0] = vec4(1.0);
}