#version 120

/* DRAWBUFFERS:2 */

const bool colortex0MipmapEnabled = true;

uniform sampler2D colortex0;

uniform float viewWidth;
uniform float viewHeight;

varying vec2 texcoord;

#include "/lib/Settings.txt"

vec3 DecodeColor(in vec3 color) {
	return pow(color, vec3(2.2)) * 1000.0;
}

vec3 EncodeColor(in vec3 color) {    // Prepares the color to be sent through a limited dynamic range pipeline
	return pow(color * 0.001, vec3(1.0 / 2.2));
}

float cubesmooth(in float x) {
	return x * x * (3.0 - 2.0 * x);
}

vec3 ComputeBloom(const int scale, vec2 offset) {    // Computes a single bloom tile, the tile's blur level is inversely proportional to its size
	// Each bloom tile uses (1.0 / scale) per-unit of the screen + (pixelSize * 2.0)
	
	vec2  pixelSize = 1.0 / vec2(viewWidth, viewHeight);
	
	vec2 coord  = texcoord;
	     coord -= offset + pixelSize;    // A pixel is added to the offset to give the bloom tile a padding
	     coord *= scale;
	
	vec2 padding = pixelSize * scale;
	
	if (coord.s <= -padding.s || coord.s >= 1.0 + padding.s
	 || coord.t <= -padding.t || coord.t >= 1.0 + padding.t)
		return vec3(0.0);
	
	
	const float range       = 2.0 * scale;    // Sample radius has to be adjusted based on the scale of the bloom tile
	const float interval    = 1.0 * scale;
	      float maxLength   = length(vec2(range));
	
	vec3  bloom       = vec3(0.0);
	float totalWeight = 0.0;
	
	for (float i = -range; i <= range; i += interval) {
		for (float j = -range; j <= range; j += interval) {
			float weight  = 1.0 - length(vec2(i, j)) / maxLength;
			      weight *= weight;
			      weight  = cubesmooth(weight);    // Apply a faux-gaussian falloff
			
			vec2 offset = vec2(i, j) * pixelSize;
			
			bloom       += pow(texture2D(colortex0, coord + offset).rgb, vec3(2.2)) * weight;
			totalWeight += weight;
		}
	}
	
	return bloom * 1000.0 / totalWeight;
}

void main() {
	vec2 pixelSize = 1.0 / vec2(viewWidth, viewHeight);
	
	vec3 bloom  = ComputeBloom(  4, vec2(0.0                         ,                          0.0));
	     bloom += ComputeBloom(  8, vec2(0.0                         , 0.25     + pixelSize.y * 2.0));
	     bloom += ComputeBloom( 16, vec2(0.125    + pixelSize.x * 2.0, 0.25     + pixelSize.y * 2.0));
	     bloom += ComputeBloom( 32, vec2(0.1875   + pixelSize.x * 4.0, 0.25     + pixelSize.y * 2.0));
	     bloom += ComputeBloom( 64, vec2(0.125    + pixelSize.x * 2.0, 0.3125   + pixelSize.y * 4.0));
	     bloom += ComputeBloom(128, vec2(0.140625 + pixelSize.x * 4.0, 0.3125   + pixelSize.y * 4.0));
	     bloom += ComputeBloom(256, vec2(0.125    + pixelSize.x * 2.0, 0.328125 + pixelSize.y * 6.0));
	
	gl_FragData[0] = vec4(EncodeColor(bloom), 1.0);
}