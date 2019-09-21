#version 410 compatibility
#define composite2
#define vsh
#define world0
#define ShaderStage 10
#include "/../shaders/lib/Syntax.glsl"

uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

uniform float sunAngle;
uniform float frameTimeCounter;

uniform float viewWidth;
uniform float viewHeight;

varying vec2 texcoord;

flat varying vec2 pixelSize;

#include "/../shaders/lib/Settings.glsl"
#include "/../shaders/lib/Utility.glsl"
#include "/../shaders/lib/Uniform/Projection_Matrices.vsh"
#include "/../shaders/lib/Uniform/Shading_Variables.glsl"
#include "/../shaders/UserProgram/centerDepthSmooth.glsl"
#include "/../shaders/lib/Uniform/Shadow_View_Matrix.vsh"

void main() {
	texcoord    = gl_MultiTexCoord0.st;
	gl_Position = ftransform();
	
	pixelSize = 1.0 / vec2(viewWidth, viewHeight);
	
	
	SetupProjection();
	
	#include "/../shaders/lib/Vertex/Shading_Setup.vsh"
}
