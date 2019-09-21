#version 410 compatibility
#define gbuffers_basic
#define vsh
#define world0
#define ShaderStage -2
#include "/../shaders/lib/Syntax.glsl"


attribute vec4 mc_Entity;

uniform mat4 gbufferModelViewInverse;

uniform vec3  cameraPosition;
uniform float frameTimeCounter;

varying mat2x3 position;

varying vec3 color;

#include "/../shaders/lib/Settings.glsl"
#include "/../shaders/lib/Utility.glsl"
#include "/../shaders/lib/Uniform/Projection_Matrices.vsh"

vec3 GetWorldSpacePosition() {
	vec3 position = transMAD(gl_ModelViewMatrix, gl_Vertex.xyz);
	
	return mat3(gbufferModelViewInverse) * position;
}

vec4 ProjectViewSpace(vec3 viewSpacePosition) {
	return vec4(projMAD(projMatrix, viewSpacePosition), viewSpacePosition.z * projMatrix[2].w);
}

#include "/../shaders/UserProgram/Terrain_Deformation.vsh"
#include "/../shaders/lib/Vertex/Vertex_Displacements.vsh"

void main() {
	SetupProjection();
	
	color = gl_Color.rgb;
	
	vec3 position  = GetWorldSpacePosition();
	     position += CalculateVertexDisplacements(position);
	     position  = position * mat3(gbufferModelViewInverse);
	
	gl_Position = ProjectViewSpace(position);
}
