/* DRAWBUFFERS:01234 */

uniform sampler2D texture;
uniform sampler2D normals;
uniform sampler2D specular;

uniform float wetness;
uniform float far;

varying vec3 color;
varying vec2 texcoord;
varying vec2 vertLightmap;

varying mat3 tbnMatrix;

varying mat2x3 position;

varying vec3 worldDisplacement;

flat varying float mcID;
flat varying float materialIDs;

#include "/lib/Settings.glsl"
#include "/lib/Debug.glsl"
#include "/lib/Utility.glsl"
#include "/lib/Uniform/Projection_Matrices.fsh"
#include "/lib/Misc/Calculate_Fogfactor.glsl"
#include "/lib/Fragment/Masks.fsh"


float LOD = 0.0;

#if defined gbuffers_hand
	#define NORMAL_MAPS
#endif

//#define SPECULARITY_MAPS

#define GetTexture(x, y) texture2D(x, y)

vec4 GetDiffuse(vec2 coord) {
	return vec4(color.rgb, 1.0) * GetTexture(texture, coord);
}

vec3 GetNormal(vec2 coord) {
#ifdef NORMAL_MAPS
	vec3 normal = GetTexture(normals, coord).xyz * 2.0 - 1.0;
#else
	vec3 normal = vec3(0.0, 0.0, 1.0);
#endif
	
	normal.xyz = normalize(tbnMatrix * normal.xyz);
	
	return normal;
}

float GetSpecularity(vec2 coord) {
#ifdef SPECULARITY_MAPS
	float specularity = texture2D(specular, coord).r;
	
	#if defined WEATHER && defined NORMAL_MAPS
		specularity = clamp01(specularity + wetness);
	#endif
	
	return specularity
#else
	return 0.0;
#endif
}

void main() {
	if (CalculateFogFactor(position[0]) >= 1.0) discard;
	
	vec4  diffuse     = GetDiffuse(texcoord); if (diffuse.a < 0.1000003) discard;
	vec3  normal      = GetNormal(texcoord);
	float specularity = GetSpecularity(texcoord);
	
	float encodedMaterialIDs = EncodeMaterialIDs(materialIDs, vec4(0.0, 0.0, 0.0, 0.0));
	
	gl_FragData[0] = vec4(0.0, 0.0, 0.0, 1.0);
	gl_FragData[1] = vec4(diffuse.rgb, 1.0);
	gl_FragData[2] = vec4(0.0);
	gl_FragData[3] = vec4(0.0);
	gl_FragData[4] = vec4(Encode4x8F(vec4(encodedMaterialIDs, specularity, vertLightmap.rg)), EncodeNormal(normal, 11.0), 0.0, 1.0);
	
	exit();
}