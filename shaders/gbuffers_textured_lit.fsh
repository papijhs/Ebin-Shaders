#version 150 compatibility

/* DRAWBUFFERS:012 */

uniform sampler2D	texture;
uniform sampler2D	normals;
uniform sampler2D	lightmap;

in vec3		color;
in vec2		texcoord;
in vec2		lightmapCoord;

in vec3		vertNormal;
in mat3		tbnMatrix;
in vec2		vertLightmap;

vec3 GetNormals(in vec2 coord) {
	vec3
	normal = texture2D(normals, coord).xyz * 2.0 - 1.0;
	normal = normalize(normal * tbnMatrix);
	
	return normal;
}

void main() {
	vec4
	diffuse		= vec4(color.rgb, 1.0);
	diffuse		*= texture2D(texture, texcoord);
//	diffuse.rgb	*= texture2D(lightmap, lightmapCoord).rgb;
	
	vec3 normal	= GetNormals(texcoord);
	
	gl_FragData[0] = vec4(diffuse.rgb, diffuse.a);
	gl_FragData[1] = vec4(vertLightmap.st, 0.0, 1.0);
	gl_FragData[2] = vec4(normal * 0.5 + 0.5, 1.0);
}