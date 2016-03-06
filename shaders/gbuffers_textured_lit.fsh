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

varying float encodedMaterialIDs;

vec4 GetDiffuse() {
	vec4 diffuse = vec4(color.rgb, 1.0);
	     diffuse *= texture2D(texture, texcoord);
	
	return diffuse;
}

vec2 EncodeNormal(vec3 normal) {
    float p = sqrt(normal.z * 8.0 + 8.0);
    return vec2(normal.xy / p + 0.5) * 0.5 + 0.5;
}

vec3 GetNormals() {
	vec3 normal    = texture2D(normals, texcoord).xyz * 2.0 - 1.0;
	     normal    = normalize(normal * tbnMatrix);
		 normal.xy = EncodeNormal(normal);
	
	return normal;
}

void main() {
	vec4 diffuse  = vec4(color.rgb, 1.0);
	     diffuse *= texture2D(texture, texcoord);
	
	vec3 normal   = GetNormals();
	
	gl_FragData[0] = vec4(diffuse.rgb, diffuse.a);
	gl_FragData[1] = vec4(vertLightmap.st, encodedMaterialIDs, 1.0);
	gl_FragData[2] = vec4(normal.xy, 0.0, 1.0);
}