#include "/../shaders/lib/Syntax.glsl"

/***********************************************************************/
#if defined vsh

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

flat varying float materialIDs;

#include "/../shaders/lib/Settings.glsl"
#include "/../shaders/lib/Utility.glsl"
#include "/../shaders/lib/Debug.glsl"
#include "/../shaders/lib/Uniform/Projection_Matrices.vsh"

#if defined gbuffers_water
#include "/../shaders/lib/Uniform/Shading_Variables.glsl"
#include "/../shaders/UserProgram/centerDepthSmooth.glsl"
#include "/../shaders/lib/Uniform/Shadow_View_Matrix.vsh"
#endif


vec2 GetDefaultLightmap() {
	vec2 lightmapCoord = mat2(gl_TextureMatrix[1]) * gl_MultiTexCoord1.st;
	
	return clamp01(lightmapCoord / vec2(0.8745, 0.9373)).rg;
}

#include "/../shaders/../shaders/block.properties"

vec3 GetWorldSpacePosition() {
	vec3 position = transMAD(gl_ModelViewMatrix, gl_Vertex.xyz);
	
#if  defined gbuffers_water
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

#include "/../shaders/lib/Vertex/Waving.vsh"
#include "/../shaders/lib/Vertex/Vertex_Displacements.vsh"

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

void main() {
	materialIDs  = BackPortID(int(mc_Entity.x));
	
#ifdef HIDE_ENTITIES
//	if (isEntity(materialIDs)) { gl_Position = vec4(-1.0); return; }
#endif
	
	SetupProjection();
	
	color        = abs(mc_Entity.x - 10.5) > 0.6 ? gl_Color.rgb : vec3(1.0);
	color        = rgb(hsv(color) * vec3(1.0, 1.25, 1.0));
	texcoord     = gl_MultiTexCoord0.st;
	vertLightmap = GetDefaultLightmap();
	
	show(int(mc_Entity.x) == 9)
	vec3 worldSpacePosition = GetWorldSpacePosition();
	
	worldDisplacement = CalculateVertexDisplacements(worldSpacePosition);
	
	position[1] = worldSpacePosition + worldDisplacement;
	position[0] = position[1] * mat3(gbufferModelViewInverse);
	
	gl_Position = ProjectViewSpace(position[0]);
	
	
	tbnMatrix = CalculateTBN(worldSpacePosition);
	
	
#if defined gbuffers_water
	#include "/../shaders/lib/Vertex/Shading_Setup.vsh"
#endif
}

#endif
/***********************************************************************/



/***********************************************************************/
#if defined fsh

uniform sampler2D texture;
uniform sampler2D normals;
uniform sampler2D specular;

uniform ivec2 atlasSize;

uniform float frameTimeCounter;
uniform float wetness;
uniform float far;

varying vec3 color;
varying vec2 texcoord;
varying vec2 vertLightmap;

varying mat3 tbnMatrix;

varying mat2x3 position;

varying vec3 worldDisplacement;

flat varying float materialIDs;

#include "/../shaders/lib/Settings.glsl"
#include "/../shaders/lib/Debug.glsl"
#include "/../shaders/lib/Utility.glsl"
#include "/../shaders/lib/Uniform/Projection_Matrices.fsh"
#include "/../shaders/lib/Misc/Calculate_Fogfactor.glsl"
#include "/../shaders/lib/Fragment/Masks.fsh"

#if defined gbuffers_water
#include "/../shaders/lib/Uniform/Shading_Variables.glsl"
#include "/../shaders/lib/Uniform/Shadow_View_Matrix.fsh"
#include "/../shaders/lib/Fragment/Calculate_Shaded_Fragment.fsh"
#include "/../shaders/lib/Fragment/Water_Waves.fsh"
#endif


float LOD;

#ifdef TERRAIN_PARALLAX
	#define GetTexture(x, y) texture2DLod(x, y, LOD)
#else
	#define GetTexture(x, y) texture2D(x, y)
#endif

vec4 GetDiffuse(vec2 coord) {
	return vec4(color.rgb, 1.0) * GetTexture(texture, coord);
}

vec3 GetNormal(vec2 coord) {
#ifdef NORMAL_MAPS
	vec3 normal = GetTexture(normals, coord).xyz;
#else
	vec3 normal = vec3(0.5, 0.5, 1.0);
#endif
	
	normal.xyz = tbnMatrix * normalize(normal.xyz * 2.0 - 1.0);
	
	return normal;
}

vec3 GetTangentNormal() {
#ifdef NORMAL_MAPS
	return texture2D(normals, texcoord).rgb;
#else
	return vec3(0.5, 0.5, 1.0);
#endif
}

float GetSpecularity(vec2 coord) {
#ifdef SPECULARITY_MAPS
	return GetTexture(specular, coord).r;
#else
	return 0.0;
#endif
}

vec2 ComputeParallaxCoordinate(vec2 coord, vec3 position) {
#if !defined TERRAIN_PARALLAX || !defined gbuffers_terrain
	return coord;
#endif
	
	LOD = textureQueryLod(texture, coord).x;
	
	cfloat parallaxDist = TERRAIN_PARALLAX_DISTANCE;
	cfloat distFade     = parallaxDist / 3.0;
	cfloat MinQuality   = 0.5;
	cfloat maxQuality   = 1.5;
	
	float intensity = clamp01((parallaxDist - length(position) * FOV / 90.0) / distFade) * 0.85 * TERRAIN_PARALLAX_INTENSITY;
	
	if (intensity < 0.01) return coord;
	
	float quality = clamp(radians(180.0 - FOV) / max1(pow(length(position), 0.25)), MinQuality, maxQuality) * TERRAIN_PARALLAX_QUALITY;
	
	vec3 tangentRay = normalize(position) * tbnMatrix;
//	
	vec2 textureRes = vec2(TEXTURE_PACK_RESOLUTION);
	
	if (atlasSize.x != atlasSize.y){ 
		tangentRay.x *= 0.5;
		textureRes.y *= 2.0;
	}
	
	vec4 tileScale   = vec4(atlasSize.x / textureRes, textureRes / atlasSize.x);
	vec2 tileCoord   = fract(coord * tileScale.xy);
	vec2 atlasCorner = floor(coord * tileScale.xy) * tileScale.zw;
	
	float stepCoeff = -tangentRay.z * 100.0 * clamp01(intensity);
	
	vec3 step    = tangentRay * vec3(0.01, 0.01, 1.0 / intensity) / quality * 0.03 * sqrt(length(position));
	     step.z *= stepCoeff;
	
	vec3  sampleRay    = vec3(0.0, 0.0, stepCoeff);
	float sampleHeight = GetTexture(normals, coord).a * stepCoeff;
	
	if (sampleRay.z <= sampleHeight) return coord;
	
	for (uint i = 0; sampleRay.z > sampleHeight && i < 150; i++) {
		sampleRay.xy += step.xy * clamp01(sampleRay.z - sampleHeight);
		sampleRay.z += step.z;
		
		sampleHeight = GetTexture(normals, fract(sampleRay.xy * tileScale.xy + tileCoord) * tileScale.zw + atlasCorner).a * stepCoeff;
	}
	
	return fract(sampleRay.xy * tileScale.xy + tileCoord) * tileScale.zw + atlasCorner;
}

/* DRAWBUFFERS:01234 */
#include "/../shaders/lib/Exit.glsl"

void main() {
	if (CalculateFogFactor(position[0], FOG_POWER) >= 1.0) discard;
	
	vec2 coord = ComputeParallaxCoordinate(texcoord, position[1]);
	
	vec4 diffuse = GetDiffuse(coord);
	if (diffuse.a < 0.1000003) discard;
	
	vec3 normal = GetNormal(coord);
	
	float specularity = GetSpecularity(coord);
	
//	gl_FragDepth = projMAD(projMatrix, position[0]).z / -position[0].z * 0.5 + 0.5;
	
#if defined WEATHER && defined NORMAL_MAPS
	specularity = clamp01(specularity + wetness);
#endif
	
#if !defined gbuffers_water
	float encodedMaterialIDs = EncodeMaterialIDs(materialIDs, vec4(0.0, 0.0, 0.0, 0.0));
	
	gl_FragData[0] = vec4(0.0, 0.0, 0.0, 1.0);
	gl_FragData[1] = vec4(diffuse.rgb, 1.0);
	gl_FragData[2] = vec4(0.0);
	gl_FragData[3] = vec4(0.0);
	gl_FragData[4] = vec4(Encode4x8F(vec4(encodedMaterialIDs, specularity, vertLightmap.rg)), EncodeNormal(normal, 11.0), 0.0, 1.0);
#else
	specularity = clamp(specularity, 0.0, 1.0 - 1.0 / 255.0);
	
	Mask mask = EmptyMask;
	
	if (abs(materialIDs - 4.0) < 0.1) {
		if (!gl_FrontFacing) discard;
		
		diffuse = vec4(0.215, 0.356, 0.533, 0.75);
		
		normal = tbnMatrix * GetWaveNormals(position[1], tbnMatrix[2]);
		
		specularity = 1.0;
		mask.water = 1.0;
	}
	
	vec3 composite  = CalculateShadedFragment(powf(diffuse.rgb, 2.2), mask, vertLightmap.r, vertLightmap.g, vec4(0.0, 0.0, 0.0, 1.0), normal.xyz * mat3(gbufferModelViewInverse), specularity, position);
	
	gl_FragData[0] = vec4(Encode4x8F(vec4(specularity, vertLightmap.g, 0.0, 0.1)), EncodeNormalU(normal.xyz, mask.water), 0.0, 1.0);
	gl_FragData[1] = vec4(0.0);
	gl_FragData[2] = vec4(1.0, 0.0, 0.0, diffuse.a);
	gl_FragData[3] = vec4(composite, diffuse.a);
	gl_FragData[4] = vec4(0.0);
#endif
	
	exit();
}

#endif
/***********************************************************************/
