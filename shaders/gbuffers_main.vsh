attribute vec4 mc_Entity;
attribute vec4 at_tangent;
attribute vec4 mc_midTexCoord;

uniform sampler2D lightmap;

uniform mat4 gbufferModelViewInverse;

uniform vec3  cameraPosition;
uniform vec3  previousCameraPosition;
uniform float frameTimeCounter;

varying vec3 color;
varying vec2 texcoord;
varying vec2 vertLightmap;

varying mat3 tbnMatrix;

varying mat2x3 position;

varying vec3 worldDisplacement;

flat varying float mcID;
flat varying float materialIDs;

#include "/lib/Settings.glsl"
#include "/lib/Utility.glsl"
#include "/lib/Debug.glsl"
#include "/lib/Uniform/Projection_Matrices.vsh"


vec2 GetDefaultLightmap() {
	vec2 lightmapCoord = mat2(gl_TextureMatrix[1]) * gl_MultiTexCoord1.st;
	
	return clamp01(lightmapCoord / vec2(0.8745, 0.9373)).rg;
}

#include "/lib/Vertex/Materials.vsh"

vec3 GetWorldSpacePosition() {
	vec3 position = transMAD(gl_ModelViewMatrix, gl_Vertex.xyz);
	
#if defined gbuffers_water
	position -= gl_NormalMatrix * gl_Normal * (norm(gl_Normal) * 0.00005 * float(abs(mc_Entity.x - 8.5) > 0.6));
#elif defined gbuffers_spidereyes
	position += gl_NormalMatrix * gl_Normal * (norm(gl_Normal) * 0.0002);
#endif
	
	return mat3(gbufferModelViewInverse) * position;
}

vec4 ProjectViewSpace(vec3 viewSpacePosition) {
#if !defined gbuffers_hand
	return vec4(projMAD(projMatrix, viewSpacePosition), viewSpacePosition.z * projMatrix[2].w);
#else
	return vec4(projMAD(gl_ProjectionMatrix, viewSpacePosition), viewSpacePosition.z * gl_ProjectionMatrix[2].w);
#endif
}

#include "/lib/Vertex/Waving.vsh"
#include "/lib/Vertex/Vertex_Displacements.vsh"

mat3 CalculateTBN(vec3 worldPosition) {
	vec3 tangent  = normalize(at_tangent.xyz);
	vec3 binormal = normalize(-cross(gl_Normal, at_tangent.xyz));
	
	tangent  += CalculateVertexDisplacements(worldPosition +  tangent) - worldDisplacement;
	binormal += CalculateVertexDisplacements(worldPosition + binormal) - worldDisplacement;
	
	tangent  = normalize(mat3(gbufferModelViewInverse) * gl_NormalMatrix *  tangent);
	binormal =           mat3(gbufferModelViewInverse) * gl_NormalMatrix * binormal ;
	
	vec3 normal = normalize(cross(-tangent, binormal));
	
	binormal = cross(tangent, normal); // Orthogonalize binormal
	
	return mat3(tangent, binormal, normal);
}

//#define HIDE_ENTITIES

void main() {
	vDebug = vec3(0.0);
	
#ifdef HIDE_ENTITIES
	if (mc_Entity.x < 0.5) { gl_Position = vec4(-1.0); return; }
#endif
	
	SetupProjection();
	
	color        = abs(mc_Entity.x - 10.5) > 0.6 ? gl_Color.rgb : vec3(1.0);
	texcoord     = gl_MultiTexCoord0.st;
	mcID         = mc_Entity.x;
	vertLightmap = GetDefaultLightmap();
	materialIDs  = GetMaterialIDs(int(mc_Entity.x));
	
	
	vec3 worldSpacePosition = GetWorldSpacePosition();
	
	worldDisplacement = CalculateVertexDisplacements(worldSpacePosition);
	
	position[1] = worldSpacePosition + worldDisplacement;
	position[0] = position[1] * mat3(gbufferModelViewInverse);
	
	gl_Position = ProjectViewSpace(position[0]);
	
	
	tbnMatrix = CalculateTBN(worldSpacePosition);
	
	
	exit();
}
