#version 120

uniform sampler2D texture;

varying vec3 color;
varying vec2 texcoord;

void main() {
	vec4 diffuse    = vec4(color.rgb, 1.0);
	     diffuse.a *= texture2D(texture, texcoord).a;
	
	gl_FragData[0] = vec4(diffuse.rgb, diffuse.a);
}