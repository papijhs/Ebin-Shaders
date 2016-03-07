#version 120

uniform mat4 gbufferProjectionInverse;

attribute vec4 mc_Entity;
attribute vec4 at_tangent;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;

uniform vec3  cameraPosition;
uniform float rainStrength;
uniform float frameTimeCounter;

uniform vec3  sunPosition;
uniform vec3  skyColor;
uniform float sunAngle;

varying vec3 color;
varying vec2 texcoord;
varying vec2 lightmapCoord;

varying vec3 vertNormal;
varying mat3 tbnMatrix;
varying vec2 vertLightmap;

varying float materialIDs;
varying float encodedMaterialIDs;

varying vec3 lightVector;
varying vec3 colorSkylight;
varying vec4 viewSpacePosition;

#define FRAME_TIME frameTimeCounter
const float pi = 3.14159265;


vec2 GetDefaultLightmap(in vec2 lightmapCoord) {    //Gets the lightmap from the default lighting engine, ignoring any texture pack lightmap. First channel is torch lightmap, second channel is sky lightmap.
	return clamp((lightmapCoord * 1.032) - 0.032, 0.0, 1.0).st;    //Default lightmap texture coordinates work somewhat as lightmaps, however they need to be adjusted to use the full range of 0.0-1.0
}

float GetMaterialIDs() {    //Gather material masks
	float materialID;
	
	switch(int(mc_Entity.x)) {
		case 31:                                //Tall Grass
		case 37:                                //Dandelion
		case 38:                                //Rose
		case 59:                                //Wheat
		case 83:                                //Sugar Cane
		case 106:                               //Vine
		case 175:                               //Double Tall Grass
					materialID = 2.0; break;    //Grass
		case 18:
					materialID = 3.0; break;    //Leaves
		case 8:
		case 9:
					materialID = 4.0; break;    //Water
		case 79:	materialID = 5.0; break;    //Ice
		default:	materialID = 1.0;
	}
	
	return materialID;
}

float EncodeMaterialIDs(in float materialIDs, in float bit0, in float bit1, in float bit2, in float bit3) {
	materialIDs += 128.0 * bit0;
	materialIDs +=  64.0 * bit1;
	materialIDs +=  32.0 * bit2;
	materialIDs +=  16.0 * bit3;
	
	materialIDs += 0.1;
	materialIDs /= 255.0;
	
	return materialIDs;
}


vec4 GetWorldSpacePosition() {
	return gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
}

vec4 WorldSpaceToProjectedSpace(in vec4 worldSpacePosition) {
	return gl_ProjectionMatrix * gbufferModelView * worldSpacePosition;
}

vec3 GetWavingWater(in vec3 position, in float magnitude) {
	float Distance = length(position.xz - cameraPosition.xz);
	
	float waveHeight = max(0.06 / max(Distance / 10.0, 1.0) - 0.006, 0.0);
	
	vec3 wave;
	wave.y  = waveHeight * sin(pi * (FRAME_TIME / 2.1 + position.x / 7.0  + position.z / 13.0));
	wave.y += waveHeight * sin(pi * (FRAME_TIME / 1.5 + position.x / 11.0 + position.z / 5.0 ));
	wave.y -= waveHeight;
	wave.y *= magnitude;
	wave.y *= float(position.y - floor(position.y) > 0.15 || position.y - floor(position.y) < 0.005);
	
	return wave;
}

vec3 GetWaves(in vec3 position) {
	vec3 wave = vec3(0.0);
	
	float skylightWeight = lightmapCoord.t;
	
	switch(int(mc_Entity.x)) {
		case 8:
		case 9:
		case 111:	wave += GetWavingWater(position, 1.0); break;
	}
	
	return wave;
}

void main() {
	color         = gl_Color.rgb;
	texcoord      = gl_MultiTexCoord0.st;
	lightmapCoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).st;
	
	vertNormal         = gl_NormalMatrix * gl_Normal;
	vertLightmap       = GetDefaultLightmap(lightmapCoord);
	materialIDs        = GetMaterialIDs();
	encodedMaterialIDs = EncodeMaterialIDs(materialIDs, 0.0, 0.0, 0.0, 0.0);
	
	
	vec4 position = GetWorldSpacePosition();
	position.xyz += cameraPosition.xyz;
	position.xyz += GetWaves(position.xyz);
	position.xyz -= cameraPosition.xyz;
	position      = WorldSpaceToProjectedSpace(position);
	gl_Position   = position;
	
	
	vec3 tangent  = normalize(gl_NormalMatrix * at_tangent.xyz);
	vec3 binormal = normalize(gl_NormalMatrix * -cross(gl_Normal, at_tangent.xyz));
	
	tbnMatrix     = mat3(
	tangent.x, binormal.x, vertNormal.x,
	tangent.y, binormal.y, vertNormal.y,
	tangent.z, binormal.z, vertNormal.z);
	
	
	viewSpacePosition  = gbufferProjectionInverse * ftransform();
	lightVector = normalize(sunAngle < 0.5 ? sunPosition : -sunPosition);
	colorSkylight = pow(skyColor, vec3(1.0 / 2.2));
}