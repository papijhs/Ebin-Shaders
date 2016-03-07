#version 120

/* DRAWBUFFERS:230 */

#define DEFERRED_SHADING

uniform sampler2D texture;
uniform sampler2D normals;
uniform sampler2D lightmap;

uniform sampler2DShadow shadow;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;
uniform mat4 shadowModelViewInverse;

uniform float sunAngle;

varying vec3 color;
varying vec2 texcoord;
varying vec2 lightmapCoord;

varying vec3 vertNormal;
varying mat3 tbnMatrix;
varying vec2 vertLightmap;

varying float encodedMaterialIDs;

varying vec3 lightVector;
varying vec3 colorSkylight;
varying vec4 viewSpacePosition;


#include "/include/ShadingStructs.fsh"

vec4 GetDiffuse() {
	vec4 diffuse = vec4(color.rgb, 1.0);
	     diffuse *= texture2D(texture, texcoord);
	
	return diffuse;
}

vec2 EncodeNormal(vec3 normal) {
    float p = sqrt(normal.z * 8.0 + 8.0);
    return vec2(normal.xy / p + 0.5) * 0.5 + 0.5;
}

vec3 GetNormal() {
	return (texture2D(normals, texcoord).xyz * 2.0 - 1.0) * tbnMatrix;
}


#include "include/ShadingFunctions.fsh"


void main() {
	vec4 diffuse  = GetDiffuse();
	vec3 normal   = GetNormal();
	
	#ifdef DEFERRED_SHADING
		gl_FragData[0] = vec4(diffuse.rgb, diffuse.a);
		gl_FragData[1] = vec4(vertLightmap.st, encodedMaterialIDs, 1.0);
		gl_FragData[2] = vec4(EncodeNormal(normal).xy, 0.0, 1.0);
	#else
		Mask mask;
		CalculateMasks(mask, encodedMaterialIDs);
		
		vec3 composite = CalculateShadedFragment(pow(diffuse.xyz, vec3(2.2)), mask, vertLightmap.s, vertLightmap.t, normal, viewSpacePosition);
		
		gl_FragData[0] = vec4(composite, diffuse.a);
	#endif
}