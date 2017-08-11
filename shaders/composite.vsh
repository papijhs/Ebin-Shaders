#version 410 compatibility
#define composite0
#define vsh
#define ShaderStage 10
#include "/lib/Syntax.glsl"

uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

uniform float sunAngle;
uniform float frameTimeCounter;

varying vec2 texcoord;

#include "/lib/Settings.glsl"
#include "/lib/Utility.glsl"
#include "/lib/Uniform/Projection_Matrices.vsh"
#include "/lib/Uniform/Shading_Variables.glsl"
#include "/UserProgram/centerDepthSmooth.glsl"
#include "/lib/Uniform/Shadow_View_Matrix.vsh"
#include "/lib/Vertex/Shading_Setup.vsh"

#define COMPOSITE0_SCALE 0.50 // [0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00]

void main() {
#if !(defined GI_ENABLED || defined AO_ENABLED || defined VOLUMETRIC_LIGHT)
	gl_Position = vec4(-1.0); return;
#endif
	
	texcoord    = gl_MultiTexCoord0.st;
	gl_Position = ftransform();
	
	gl_Position.xy = ((gl_Position.xy * 0.5 + 0.5) * COMPOSITE0_SCALE) * 2.0 - 1.0;
	
	SetupProjection();
	SetupShading();
}