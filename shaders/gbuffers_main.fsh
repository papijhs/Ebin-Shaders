/* DRAWBUFFERS:012345 */

uniform sampler2D texture;
uniform sampler2D normals;
uniform sampler2D specular;
uniform sampler2D noisetex;

uniform float frameTimeCounter;
uniform float far;
uniform float wetness;
uniform ivec2 atlasSize;

varying vec3 color;
varying vec2 texcoord;

varying mat3 tbnMatrix;
varying vec2 vertLightmap;

varying float mcID;
varying float materialIDs;

varying vec3 viewSpacePosition;
varying vec3 worldPosition;

varying vec3 worldNormal;
varying float tbnIndex;
varying float waterMask;

#include "/lib/Misc/Menu_Initializer.glsl"
#include "/lib/Settings.glsl"
#include "/lib/Utility.glsl"
#include "/lib/Debug.glsl"
#include "/lib/Misc/Calculate_Fogfactor.glsl"
#include "/lib/Fragment/Masks.fsh"

#if defined gbuffers_water
#include "/lib/Uniform/Global_Composite_Variables.glsl"
#include "/lib/Fragment/Calculate_Shaded_Fragment.fsh"
#endif

vec4 GetDiffuse(vec2 coord) {
	return vec4(color.rgb, 1.0) * texture2D(texture, coord);
}

vec3 GetNormal(vec2 coord) {
#ifdef NORMAL_MAPS
	vec3 normal = texture2D(normals, coord).xyz;
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
	vec2 specular = texture2D(specular, coord).rg;
#else
	vec2 specular = vec2(0.0);
#endif
	
	return specular;
}

vec2 EncodeNormalData(vec3 normalTexture, float tbnIndex) {
	vec2 encode;
	
	encode.r = (tbnIndex + 8.0 * waterMask) / 16.0;
	encode.g = Encode16(normalTexture.xy);
	
	return encode;
}


void main() {
	if (CalculateFogFactor(viewSpacePosition, FOG_POWER) >= 1.0) discard;
	
	vec2 coord = texcoord;
	
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
