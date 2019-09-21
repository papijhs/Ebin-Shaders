#version 410 compatibility
#define composite0
#define vsh
#define ShaderStage 10
#include "/../shaders/lib/Syntax.glsl"

uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

uniform float sunAngle;
uniform float frameTimeCounter;

varying vec2 texcoord;

#include "/../shaders/lib/Settings.glsl"
#include "/../shaders/lib/Utility.glsl"
#include "/../shaders/lib/Uniform/Projection_Matrices.vsh"
#include "/../shaders/lib/Uniform/Shading_Variables.glsl"
#include "/../shaders/UserProgram/centerDepthSmooth.glsl"
#include "/../shaders/lib/Uniform/Shadow_View_Matrix.vsh"

void main() {
#if defined GI_ENABLED || defined AO_ENABLED || defined VOLUMETRIC_LIGHT
	texcoord    = gl_MultiTexCoord0.st;
	gl_Position = ftransform();
	
	gl_Position.xy = ((gl_Position.xy * 0.5 + 0.5) * COMPOSITE0_SCALE) * 2.0 - 1.0;
	
	
	SetupProjection();
	
	#include "/../shaders/lib/Vertex/Shading_Setup.vsh"
#else
	gl_Position = vec4(-1.0);
#endif
}
