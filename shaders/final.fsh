#version 120

uniform sampler2D colortex0;
uniform sampler2D colortex2;

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

vec3 Uncharted2Tonemap(in vec3 color) {
	const float A = 0.15, B = 0.5, C = 0.1, D = 0.2, E = 0.02, F = 0.3, W = 11.2;
	const float whiteScale = 1.0 / (((W * (A * W + C * B) + D * E) / (W * (A * W + B) + D * F)) - E / F);
	const float ExposureBias = 2.3;
	
	vec3 curr = ExposureBias * color;
	     curr = ((curr * (A * curr + C * B) + D * E) / (curr * (A * curr + B) + D * F)) - E / F;
	
	color = curr * whiteScale;
	
	return pow(color, vec3(1.0 / 2.2));
}

vec3 GetBloom(const int scale, vec2 offset) {
	vec2 pixelSize = 1.0 / vec2(viewWidth, viewHeight);
	
	vec2 coord  = texcoord;
	     coord /= scale;
	     coord += offset + pixelSize;
	
	return DecodeColor(texture2D(colortex2, coord).rgb);
}

void main() {
	vec3 color = DecodeColor(texture2D(colortex0, texcoord).rgb);
	
	vec2 pixelSize = 1.0 / vec2(viewWidth, viewHeight);
	
	// These function calls should be identical to those in composite2.fsh
	vec3 bloom  = GetBloom(  4, vec2(0.0                         ,                          0.0));
	     bloom += GetBloom(  8, vec2(0.0                         , 0.25     + pixelSize.y * 2.0));
	     bloom += GetBloom( 16, vec2(0.125    + pixelSize.x * 2.0, 0.25     + pixelSize.y * 2.0));
	     bloom += GetBloom( 32, vec2(0.1875   + pixelSize.x * 4.0, 0.25     + pixelSize.y * 2.0));
	     bloom += GetBloom( 64, vec2(0.125    + pixelSize.x * 2.0, 0.3125   + pixelSize.y * 4.0));
	     bloom += GetBloom(128, vec2(0.140625 + pixelSize.x * 4.0, 0.3125   + pixelSize.y * 4.0));
	     bloom += GetBloom(256, vec2(0.125    + pixelSize.x * 2.0, 0.328125 + pixelSize.y * 6.0));
	     bloom /= 7.0;
	
	color = mix(color, pow(bloom, vec3(1.3)), 0.125);
	
	gl_FragData[0] = vec4(Uncharted2Tonemap(color), 1.0);
}