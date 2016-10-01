#version 410 compatibility
#define composite2
#define vsh
#define ShaderStage 10
#include "/lib/Syntax.glsl"

uniform mat4 gbufferModelView;
uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

uniform float sunAngle;
uniform float frameTimeCounter;

uniform float viewWidth;
uniform float viewHeight;

varying vec2 texcoord;
varying vec2 pixelSize;

#include "/lib/Settings.glsl"
#include "/lib/Utility.glsl"
#include "/lib/Uniform/Projection_Matrices.vsh"
#include "/lib/Uniform/Shading_Variables.glsl"
#include "/lib/Uniform/Shadow_View_Matrix.vsh"

void main() {
	texcoord    = gl_MultiTexCoord0.st;
	gl_Position = ftransform();
	
	pixelSize = 1.0 / vec2(viewWidth, viewHeight);
	
	
	SetupProjection();
	
	#include "/lib/Vertex/Shading_Setup.vsh"
}
