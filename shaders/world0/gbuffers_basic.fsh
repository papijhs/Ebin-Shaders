#include "/../shaders/lib/GLSL_Version.glsl"
#define gbuffers_basic
#define fsh
#define world0
#define ShaderStage -1
#include "/../shaders/lib/Syntax.glsl"


/* DRAWBUFFERS:1 */

varying vec3 color;

void main() {
	gl_FragData[0] = vec4(color.rgb, 1.0);
}
