#version 120

/* DRAWBUFFERS:230 */

uniform sampler2D texture;
uniform sampler2D normals;
uniform sampler2D lightmap;

varying vec3 color;
varying vec2 texcoord;
varying vec2 lightmapCoord;

varying vec3 vertNormal;
varying mat3 tbnMatrix;
varying vec2 vertLightmap;

vec4 GetDiffuse() {
	vec4 diffuse = vec4(color.rgb, 1.0);
	     diffuse *= texture2D(texture, texcoord);
	
	return diffuse;
}

vec3 GetNormals() {
	vec3 normal = texture2D(normals, texcoord).xyz * 2.0 - 1.0;
	     normal = normalize(normal * tbnMatrix);
	
	return normal;
}

void main() {
	vec4 diffuse  = vec4(color.rgb, 1.0);
	     diffuse *= texture2D(texture, texcoord);
	
	vec3 normal   = GetNormals();
	
	gl_FragData[0] = vec4(diffuse.rgb, diffuse.a);
	gl_FragData[1] = vec4(vertLightmap.st, 0.0, 1.0);
	gl_FragData[2] = vec4(normal * 0.5 + 0.5, 1.0);
}