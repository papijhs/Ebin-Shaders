/* DRAWBUFFERS:012345 */

uniform sampler2D texture;
uniform sampler2D normals;
uniform sampler2D specular;
uniform sampler2D noisetex;

uniform ivec2 atlasSize;

uniform float frameTimeCounter;
uniform float far;

varying vec3 color;
varying vec2 texcoord;

varying mat3 tbnMatrix;

varying vec3 viewSpacePosition;
varying vec3 worldPosition;
varying vec3 worldNormal;

varying vec2 vertLightmap;

varying float mcID;
varying float materialIDs;

varying float tbnIndex;

#include "/lib/Misc/Menu_Initializer.glsl"
#include "/lib/Settings.glsl"
#include "/lib/Utility.glsl"
#include "/lib/Debug.glsl"
#include "/lib/Uniform/Projection_Matrices.fsh"
#include "/lib/Misc/Calculate_Fogfactor.glsl"
#include "/lib/Fragment/Masks.fsh"

#if defined gbuffers_water
#include "/lib/Uniform/Shading_Variables.glsl"
#include "/lib/Uniform/Shadow_View_Matrix.fsh"
#include "/lib/Fragment/Calculate_Shaded_Fragment.fsh"
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

#include "/lib/Misc/Get3DNoise.glsl"

vec2 GetSpecularity(vec2 coord) {
#ifdef SPECULARITY_MAPS
	vec2 specular = GetTexture(specular, coord).rg;
#else
	vec2 specular = vec2(0.0);
#endif
	
	return specular;
}

vec2 EncodeNormalData(vec3 normalTexture, float tbnIndex) {
	vec2 encode;
	
	encode.r = (tbnIndex + 8.0 * float(abs(mcID - 8.5) < 0.6)) / 16.0;
	encode.g = Encode16(normalTexture.xy);
	
	return encode;
}

vec2 ComputeParallaxCoordinate(vec2 coord, vec3 viewSpacePosition) {
#if !defined TERRAIN_PARALLAX || !defined gbuffers_terrain
	return coord;
#endif
	
	LOD = textureQueryLod(texture, coord).x;
	
	cfloat parallaxDist = 12.0;
	cfloat distFade     =  4.0;
	cfloat MinQuality   =  0.5;
	cfloat maxQuality   =  1.5;
	
	float intensity = clamp01((parallaxDist - length(viewSpacePosition) * FOV / 90.0) / distFade);
	
	if (intensity < 0.01) return coord;
	
	float quality = clamp(radians(180.0 - FOV) / max1(pow(length(viewSpacePosition), 0.25)), MinQuality, maxQuality);
	
	vec3 tangentRay = normalize(viewSpacePosition * tbnMatrix);
	
	float tileScale  = atlasSize.x / TEXTURE_PACK_RESOLUTION;
	vec2  tileCoord  = fract(coord * tileScale);
	vec2 atlasCorner = floor(coord * tileScale) / tileScale;
	
	vec3 sampleRay = vec3(0.0, 0.0, 1.0);
	
	vec3 step = tangentRay * vec3(0.01, 0.01, 1.0 / intensity) / quality * 0.03 * sqrt(length(viewSpacePosition));
	
	float sampleHeight = GetTexture(normals, coord).a;
	
	if (sampleRay.z <= sampleHeight) return coord;
	
	float stepCoeff = -tangentRay.z * 64.0;
	
	for (uint i = 0; sampleRay.z > sampleHeight && i < 150; i++) {
		sampleRay.xy += step.xy * min1((sampleRay.z - sampleHeight) * stepCoeff);
		sampleRay.z += step.z;
		
		sampleHeight = GetTexture(normals, fract(sampleRay.xy * tileScale + tileCoord) / tileScale + atlasCorner).a;
	}
	
	
	return fract(sampleRay.xy * tileScale + tileCoord) / tileScale + atlasCorner;
}

void main() {
	if (CalculateFogFactor(viewSpacePosition, FOG_POWER) >= 1.0) discard;
	
	vec2 coord = ComputeParallaxCoordinate(texcoord, viewSpacePosition);
	
	
	vec4 diffuse = GetDiffuse(coord);
	if (diffuse.a < 0.1000003) discard;
	
	vec3 normal = GetNormal(coord);
	
	vec2 specularity = GetSpecularity(coord);	
	
	
#if !defined gbuffers_water
	float encodedMaterialIDs = EncodeMaterialIDs(materialIDs, vec4(specularity.g, 0.0, 0.0, 0.0));
	
	vec2 encode = vec2(Encode16(vec2(specularity.r, vertLightmap.g)), Encode16(vec2(vertLightmap.r, encodedMaterialIDs)));
	
	gl_FragData[0] = vec4(0.0, 0.0, 0.0, 1.0);
	gl_FragData[1] = vec4(diffuse.rgb, 1.0);
	gl_FragData[2] = vec4(0.0);
	gl_FragData[3] = vec4(0.0);
	gl_FragData[4] = vec4(EncodeNormal(normal.xyz), encode.r, 1.0);
	gl_FragData[5] = vec4(encode.g, 0.0, 0.0, 1.0);
#else
	float encode = Encode16(vec2(specularity.r, vertLightmap.g));
	
	vec2 encodedNormal = EncodeNormalData(GetTangentNormal(), tbnIndex);
	
	Mask mask;
	
	if (abs(mcID - 8.5) < 0.6) diffuse = vec4(0.215, 0.356, 0.533, 0.75);
	
	vec3 composite  = CalculateShadedFragment(mask, vertLightmap.r, vertLightmap.g, vec3(0.0), normal.xyz, specularity.r, viewSpacePosition);
	     composite *= pow(diffuse.rgb, vec3(2.2));
	
	gl_FragData[0] = vec4(encodedNormal, encode, 1.0);
	gl_FragData[1] = vec4(0.0);
	gl_FragData[2] = vec4(1.0, 0.0, 0.0, diffuse.a);
	gl_FragData[3] = vec4(composite, diffuse.a);
#endif
	
	exit();
}
