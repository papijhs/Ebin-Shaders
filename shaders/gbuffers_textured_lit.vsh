#version 120

attribute vec4 mc_Entity;
attribute vec4 at_tangent;

varying vec3 color;
varying vec2 texcoord;
varying vec2 lightmapCoord;

varying vec3 vertNormal;
varying mat3 tbnMatrix;
varying vec2 vertLightmap;

vec2 GetDefaultLightmap(in vec2 lightmapCoord) {    //Gets the lightmap from the default lighting engine, ignoring any texture pack lightmap. First channel is torch lightmap, second channel is sky lightmap.
	return clamp((lightmapCoord * 1.032) - 0.032, 0.0, 1.0).st;    //Default lightmap texture coordinates work somewhat as lightmaps, however they need to be adjusted to use the full range of 0.0-1.0
}

float GetMaterialIDs() {    //Gather materials
	float materialID;
	
	switch(int(mc_Entity.x)) {
		case 31:                                //Tall Grass
		case 37:                                //Dandelion
		case 38:                                //Rose
		case 59:                                //Wheat1.
		case 83:                                //Sugar Cane
		case 106:                               //Vine
		case 175:                               //Double Tall Grass
					materialID = 2.0; break;    //Translucent blocks
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

void main() {
	color         = gl_Color.rgb;
	texcoord      = gl_MultiTexCoord0.st;
	lightmapCoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).st;
	vertNormal    = gl_Normal;
	vertLightmap  = GetDefaultLightmap(lightmapCoord);
	
	gl_Position = ftransform();
	
	
	vec3 tangent  = normalize(at_tangent.xyz);
	vec3 binormal = normalize(-cross(gl_Normal, at_tangent.xyz));
	
	tbnMatrix     = mat3(
	tangent.x, binormal.x, vertNormal.x,
	tangent.y, binormal.y, vertNormal.y,
	tangent.z, binormal.z, vertNormal.z);
}