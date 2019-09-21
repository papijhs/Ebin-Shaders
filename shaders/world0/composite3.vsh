#version 410 compatibility
#define composite3
#define vsh
#define world0
#define ShaderStage 10
#include "/../shaders/lib/Syntax.glsl"

uniform float viewWidth;
uniform float viewHeight;

varying vec2 texcoord;

flat varying vec2 pixelSize;

#include "/../shaders/lib/Settings.glsl"
#include "/../shaders/lib/Utility.glsl"


void main() {
#ifdef BLOOM_ENABLED
	texcoord    = gl_MultiTexCoord0.st;
	gl_Position = ftransform();
	
	pixelSize = 1.0 / vec2(viewWidth, viewHeight);
	
	
	vec2 vertexScale = vec2(0.25 + pixelSize.x * 2.0, 0.375 + pixelSize.y * 4.0);
	
	gl_Position.xy = ((gl_Position.xy * 0.5 + 0.5) * vertexScale) * 2.0 - 1.0; // Crop the vertex to only cover the areas that are being used
	
	texcoord *= vertexScale; // Compensate for the vertex adjustment to make this a true "crop" rather than a "downscale"
	
#else
	gl_Position = vec4(-1.0);
#endif
}
