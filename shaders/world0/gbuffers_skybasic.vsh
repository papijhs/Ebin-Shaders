#version 410 compatibility
#define gbuffers_skybasic
#define vsh
#define ShaderStage -2
#include "/../shaders/lib/Syntax.glsl"

void main() {
	gl_Position = vec4(-1.0);
}
