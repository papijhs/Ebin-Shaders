#version 120

uniform sampler2D texture;

varying vec3 color;
varying vec2 texcoord;

varying vec3 vertNormal;

void main() {
	vec4 diffuse  = vec4(color.rgb, 1.0);
	     diffuse *= texture2D(texture, texcoord);
	
	float NdotL = max(0.0, dot(vertNormal, vec3(0.0, 0.0, 1.0)));
	
	gl_FragData[0] = vec4(1.0 - diffuse.rgb * NdotL, diffuse.a);
	gl_FragData[1] = vec4(vertNormal * 0.5 + 0.5, 1.0);
}