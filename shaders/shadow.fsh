#version 150 compatibility

uniform sampler2D	texture;

in vec3		color;
in vec2		texcoord;

void main() {
	vec4
	diffuse		= vec4(color.rgb, 1.0);
	diffuse.a	*= texture2D(texture, texcoord).a;
	
	gl_FragData[0] = vec4(diffuse.rgb, diffuse.a);
}