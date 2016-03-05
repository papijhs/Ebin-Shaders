#version 150 compatibility

/*
attribute vec4 mc_Entity
attribute vec4 at_tangent*/ in vec4 mc_Entity; in vec4 at_tangent;

out vec3	color;
out vec2	texcoord;
out vec2	lightmapCoord;

out vec3	vertNormal;
out mat3	tbnMatrix;
out vec2	vertLightmap;

vec2 GetDefaultLightmap(in vec2 lightmapCoord) {		//Gets the lightmap from the default lighting engine, ignoring any texture pack lightmap. First channel is sky lightmap, second channel is torch lightmap.
	return clamp((lightmapCoord * 33.05 / 32.0) - 1.05 / 32.0, 0.0, 1.0).ts;
}

void main() {
	color			= gl_Color.rgb;
	texcoord		= gl_MultiTexCoord0.st;
	lightmapCoord	= (gl_TextureMatrix[1] * gl_MultiTexCoord1).st;
	vertNormal		= gl_Normal;
	vertLightmap	= GetDefaultLightmap(lightmapCoord);
	
	gl_Position	= ftransform();
	
	
	vec3 tangent	= normalize(at_tangent.xyz);
	vec3 binormal	= normalize(-cross(gl_Normal, at_tangent.xyz));
	
	tbnMatrix		= mat3(
	tangent.x, binormal.x, vertNormal.x,
	tangent.y, binormal.y, vertNormal.y,
	tangent.z, binormal.z, vertNormal.z);
}