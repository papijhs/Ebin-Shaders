#version 410 compatibility
#define composite3
#define fsh
#define ShaderStage 3
#include "/lib/Syntax.glsl"

/* DRAWBUFFERS:1 */

const bool colortex3MipmapEnabled = true;

uniform sampler2D colortex3;

uniform float viewWidth;
uniform float viewHeight;

varying vec2 texcoord;

flat varying vec2 pixelSize;

#include "/lib/Settings.glsl"
#include "/lib/Utility.glsl"
#include "/lib/Debug.glsl"

vec3 EbinBloomTile(cfloat scale, vec2 offset) { // Computes a single bloom tile, the tile's blur level is inversely proportional to its size
	// Each bloom tile uses (1.0 / scale + pixelSize * 2.0) texcoord-units of the screen
	
	vec2 coord = (texcoord - (offset + pixelSize)) * scale; // A pixel is added to the offset to give the bloom tile a padding
	
	vec2 padding = pixelSize * scale;
	
	if (any(greaterThanEqual(abs(coord - 0.5), padding + 0.5)))
		return vec3(0.0);
	
	
	float lod = log2(scale);
	
	cfloat range     = 4.0 * scale;
	cfloat interval  = 1.0 * scale;
	float  maxLength = length(vec2(range));
	
	vec3  bloom       = vec3(0.0);
	float totalWeight = 0.0;
	
	for (float i = -range; i <= range; i += interval) {
		for (float j = -range; j <= range; j += interval) {
			float weight  = 1.0 - length(vec2(i, j)) / maxLength;
			      weight  = cubesmooth(pow2(weight));
			
			vec2 offset = vec2(i, j) * pixelSize;
			
			bloom       += DecodeColor(texture2DLod(colortex3, coord + offset, lod).rgb) * weight;
			totalWeight += weight;
		}
	}
	
	return bloom / totalWeight;
}

vec3 EbinBloom() {
	vec3 bloom = vec3(0.0);
	bloom += EbinBloomTile(  4, vec2(0.0                         ,                          0.0));
	bloom += EbinBloomTile(  8, vec2(0.0                         , 0.25     + pixelSize.y * 2.0));
	bloom += EbinBloomTile( 16, vec2(0.125    + pixelSize.x * 2.0, 0.25     + pixelSize.y * 2.0));
	bloom += EbinBloomTile( 32, vec2(0.1875   + pixelSize.x * 4.0, 0.25     + pixelSize.y * 2.0));
	bloom += EbinBloomTile( 64, vec2(0.125    + pixelSize.x * 2.0, 0.3125   + pixelSize.y * 4.0));
	bloom += EbinBloomTile(128, vec2(0.140625 + pixelSize.x * 4.0, 0.3125   + pixelSize.y * 4.0));
	
	return bloom;
}

vec3 SeishinBloomTile(float lod, vec2 offset) {
	vec3 bloom  = vec3(0.0);
	float total = 0.0;
	
	float scale = pow(2.0, lod);
	vec2 coord  = (texcoord - offset) * scale;
	
	if (coord.s > -0.1 && coord.t > -0.1 && coord.s < 1.1 && coord.t < 1.1) {
		for (int i = -4; i < 4; i++) {
			for (int j = -4; j < 4; j++) {
				float weight = pow2(clamp01(1.0 - length(vec2(i, j)) / 4.0) * 1.1);
				vec2 bcoord  = (texcoord - offset + vec2(i, j) / vec2(viewWidth, viewHeight)) * scale;
				
				if (weight > 0) {
					bloom += DecodeColor(texture2DLod(colortex3, bcoord, lod).rgb) * weight;
					total += weight;
				}
			}
		}
		
		bloom /= total;
	}
	return bloom;
}

vec3 SeishinBloom() {
	vec3 bloom = vec3(0.0);
	bloom += SeishinBloomTile(2.0, vec2(0.0, 0.0));
	bloom += SeishinBloomTile(3.0, vec2(0.3, 0.0));
	bloom += SeishinBloomTile(4.0, vec2(0.0, 0.3));
	bloom += SeishinBloomTile(5.0, vec2(0.1, 0.3));
	bloom += SeishinBloomTile(6.0, vec2(0.2, 0.3));
	bloom += SeishinBloomTile(7.0, vec2(0.3, 0.3));
	
	return bloom * DecodeColor(0.1);
}

void main() {
	gl_FragData[0] = vec4(EncodeColor(SeishinBloom()), 1.0);
	
	exit();
}
