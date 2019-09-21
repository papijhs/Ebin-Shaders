#version 410 compatibility
#define gbuffers_shadow
#define fsh
#define world0
#define ShaderStage -1
#include "/../shaders/lib/Syntax.glsl"


uniform sampler2D texture;

varying vec4 color;
varying vec2 texcoord;

flat varying vec3 vertNormal;


void main() {
	vec4 diffuse = color * texture2D(texture, texcoord);
	
	gl_FragData[0] = diffuse;
	gl_FragData[1] = vec4(vertNormal.xy * 0.5 + 0.5, 0.0, 1.0);
}
