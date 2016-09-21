#version 410 compatibility
#define gbuffers_shadow
#define vsh
#define ShaderStage -2
#include "/lib/Syntax.glsl"


attribute vec4 mc_Entity;
attribute vec4 at_tangent;

uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

uniform float far;
uniform float sunAngle;
uniform float frameTimeCounter;

varying vec4 color;
varying vec2 texcoord;
varying vec2 lightmapCoord;

varying vec3 vertNormal;

#include "/lib/Settings.glsl"
#include "/lib/Utility.glsl"
#include "/lib/Uniform/ShadowViewMatrix.vsh"

vec3 GetWorldSpacePositionShadow() {
	return transMAD(shadowModelViewInverse, projMAD(shadowProjectionInverse, ftransform().xyz));
}


#include "/lib/Vertex/Waving.vsh"
#include "/lib/Vertex/Vertex_Displacements.vsh"

#include "/lib/Misc/Bias_Functions.glsl"

vec4 ProjectShadowMap(vec4 position) {
	position = vec4(projMAD(shadowProjection, transMAD(shadowViewMatrix, position.xyz)), position.z * shadowProjection[2].w + shadowProjection[3].w);
	
	float biasCoeff = GetShadowBias(position.xy);
	
	position.xy /= biasCoeff;
	
	position.z += 0.001 * sin(max0(vertNormal.z)); // Offset the z-coordinate to reduce shadow acne
	position.z += 0.000005 / (abs(position.x) + 1.0);
	position.z += 0.006 * pow2(biasCoeff);
	
	position.z /= 4.0; // Shrink the domain of the z-buffer. This counteracts the noticable issue where far terrain would not have shadows cast, especially when the sun was near the horizon
	
	return position;
}


void main() {
	if (abs(mc_Entity.x - 8.5) < 0.6) { gl_Position = vec4(-1.0); return; } // Discard water
	
#ifdef CUSTOM_TIME_CYCLE
	CalculateShadowView();
#endif
	
	color         = gl_Color;
	texcoord      = gl_MultiTexCoord0.st;
	lightmapCoord = mat2(gl_TextureMatrix[1]) * gl_MultiTexCoord1.st;
	
	vertNormal    = normalize(mat3(shadowViewMatrix) * gl_Normal);
	
	
	vec3 position = GetWorldSpacePositionShadow();
	
	position += CalculateVertexDisplacements(position, lightmapCoord.g);
	
	gl_Position = ProjectShadowMap(position.xyzz);
	
	
	color.rgb *= pow(max0(vertNormal.z), 1.0 / 2.2);
	
	if (   mc_Entity.x == 0 // If the vertex is an entity
		&& abs(position.x) < 1.0
		&& position.y > -0.1 &&  position.y < 2.0 // Check if the vertex is A bounding box around the player, so that at least non-near entities still cast shadows
		&& abs(position.z) < 1.0
	) {
	#ifndef PLAYER_SHADOW
		color.a = 0.0;
	#elif !defined PLAYER_GI_BOUNCE
		color.rgb = vec3(0.0);
	#endif
	}
}
