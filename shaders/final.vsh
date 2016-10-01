#version 410 compatibility
#define final
#define vsh
#define ShaderStage 10
#include "/lib/Syntax.glsl"

uniform float viewWidth;
uniform float viewHeight;

varying vec2 texcoord;
varying vec2 pixelSize;

#include "/lib/Settings.glsl"
#include "/lib/Utility.glsl"
#include "/lib/Uniform/Projection_Matrices.vsh"

void main() {
	texcoord    = gl_MultiTexCoord0.st;
	gl_Position = ftransform();
	
	pixelSize = 1.0 / vec2(viewWidth, viewHeight);
	
	SetupProjection();
}
