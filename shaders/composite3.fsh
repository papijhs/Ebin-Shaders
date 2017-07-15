#version 410 compatibility
#define composite3
#define fsh
#define ShaderStage 3
#include "/lib/Syntax.glsl"

/* DRAWBUFFERS:1 */

const bool colortex3MipmapEnabled = true;

uniform sampler2D colortex3;
uniform sampler2D colortex1;

uniform float viewWidth;
uniform float viewHeight;

varying vec2 texcoord;

flat varying vec2 pixelSize;

#include "/lib/Settings.glsl"
#include "/lib/Utility.glsl"
#include "/lib/Debug.glsl"

vec3 SeishinBloomTile(cfloat lod, vec2 offset) {
	vec2 coord = (texcoord - offset) * exp2(lod);
	vec2 scale = pixelSize * exp2(lod);
	
	if (any(greaterThanEqual(abs(coord - 0.5), scale + 0.5)))
		return vec3(0.0);
	
	vec3  bloom       = vec3(0.0);
	float totalWeight = 0.0;
	
	for (int y = -3; y <= 3; y++) {
		for (int x = -3; x <= 3; x++) {
			float weight = pow2(clamp01(1.0 - length(vec2(x, y)) / 4.0) * 1.1);
			
			bloom += DecodeColor(texture2DLod(colortex3, coord + vec2(x, y) * scale, lod).rgb) * weight;
			totalWeight += weight;
		}
	}
	
	return bloom / totalWeight;
}

vec3 SeishinBloom() {
	vec3 bloom = vec3(0.0);
	bloom += SeishinBloomTile(2.0, vec2(0.0                         ,                        0.0));
	bloom += SeishinBloomTile(3.0, vec2(0.0                         , 0.25   + pixelSize.y * 2.0));
	bloom += SeishinBloomTile(4.0, vec2(0.125    + pixelSize.x * 2.0, 0.25   + pixelSize.y * 2.0));
	bloom += SeishinBloomTile(5.0, vec2(0.1875   + pixelSize.x * 4.0, 0.25   + pixelSize.y * 2.0));
	bloom += SeishinBloomTile(6.0, vec2(0.125    + pixelSize.x * 2.0, 0.3125 + pixelSize.y * 4.0));
	bloom += SeishinBloomTile(7.0, vec2(0.140625 + pixelSize.x * 4.0, 0.3125 + pixelSize.y * 4.0));
	
	return bloom;
}

void main() {
	gl_FragData[0] = vec4(EncodeColor(SeishinBloom()), 1.0);
	
	exit();
}
