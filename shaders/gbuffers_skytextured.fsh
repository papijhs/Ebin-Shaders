#version 150 compatibility

/* DRAWBUFFERS:012 */

uniform sampler2D	texture;

in vec3		color;
in vec2		texcoord;

void main() {
	vec4
	diffuse		= texture2D(texture, texcoord);
	diffuse.rgb	*= color;
	
	gl_FragData[0] = diffuse;
}