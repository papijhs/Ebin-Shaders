#version 410 compatibility
#define final
#define fsh
#define ShaderStage 7
#include "/lib/Syntax.glsl"

uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D gdepthtex;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousModelView;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

uniform float viewWidth;
uniform float viewHeight;

varying vec2 texcoord;
varying vec2 pixelSize;

#include "/lib/Settings.glsl"
#include "/lib/Utility.glsl"
#include "/lib/Debug.glsl"
#include "/lib/Uniform/Projection_Matrices.fsh"
#include "/lib/Fragment/Masks.fsh"

vec3 GetColor(vec2 coord) {
	return DecodeColor(texture2D(colortex3, coord).rgb);
}

float GetDepth(vec2 coord) {
	return texture2D(gdepthtex, coord).x;
}


void MotionBlur(io vec3 color, float depth, float handMask) {
#ifdef MOTION_BLUR
	if (handMask > 0.5) return;
	
	vec4 position = vec4(vec3(texcoord, depth) * 2.0 - 1.0, 1.0); // Signed [-1.0 to 1.0] screen space position
	
	vec4 previousPosition      = gbufferModelViewInverse * projInverseMatrix * position; // Un-project and un-rotate
	     previousPosition     /= previousPosition.w; // Linearize
	     previousPosition.xyz += cameraPosition - previousCameraPosition; // Add the world-space difference from the previous frame
	     previousPosition      = projMatrix * gbufferPreviousModelView * previousPosition; // Re-rotate and re-project using the previous frame matrices
	     previousPosition.st  /= previousPosition.w; // Un-linearize, swizzle to avoid correcting irrelivant components
	
	cfloat intensity = MOTION_BLUR_INTENSITY * 0.5;
	cfloat maxVelocity = MAX_MOTION_BLUR_AMOUNT * 0.1;
	
	vec2 velocity = (position.st - previousPosition.st) * intensity; // Screen-space motion vector
	     velocity = clamp(velocity, vec2(-maxVelocity), vec2(maxVelocity));
	
	#ifdef VARIABLE_MOTION_BLUR_SAMPLES
	float sampleCount = length(velocity / pixelSize) * VARIABLE_MOTION_BLUR_SAMPLE_COEFFICIENT; // There should be exactly 1 sample for every pixel when the sample coefficient is 1.0
	      sampleCount = floor(clamp(sampleCount, 1, MAX_MOTION_BLUR_SAMPLE_COUNT));
	#else
	cfloat sampleCount = CONSTANT_MOTION_BLUR_SAMPLE_COUNT;
	#endif
	
	vec2 sampleStep = velocity / sampleCount;
	
	color *= 0.001;
	
	for(float i = 1.0; i <= sampleCount; i++) {
		vec2 coord = texcoord - sampleStep * i;
		
		color += pow(texture2D(colortex3, clampScreen(coord, pixelSize)).rgb, vec3(2.2));
	}
	
	color *= 1000.0 / max(sampleCount + 1.0, 1.0);
#endif
}

vec3 GetBloomTile(cint scale, vec2 offset) {
	vec2 coord  = texcoord;
	     coord /= scale;
	     coord += offset + pixelSize;
	
	return DecodeColor(texture2D(colortex1, coord).rgb);
}

vec3[8] GetBloom() {
	vec3[8] bloom;
	
#ifdef BLOOM_ENABLED
	// These arguments should be identical to those in composite2.fsh
	bloom[1] = GetBloomTile(  4, vec2(0.0                         ,                          0.0));
	bloom[2] = GetBloomTile(  8, vec2(0.0                         , 0.25     + pixelSize.y * 2.0));
	bloom[3] = GetBloomTile( 16, vec2(0.125    + pixelSize.x * 2.0, 0.25     + pixelSize.y * 2.0));
	bloom[4] = GetBloomTile( 32, vec2(0.1875   + pixelSize.x * 4.0, 0.25     + pixelSize.y * 2.0));
	bloom[5] = GetBloomTile( 64, vec2(0.125    + pixelSize.x * 2.0, 0.3125   + pixelSize.y * 4.0));
	bloom[6] = GetBloomTile(128, vec2(0.140625 + pixelSize.x * 4.0, 0.3125   + pixelSize.y * 4.0));
	bloom[7] = GetBloomTile(256, vec2(0.125    + pixelSize.x * 2.0, 0.328125 + pixelSize.y * 6.0));
	
	bloom[0] = vec3(0.0);
	
	for (uint index = 1; index <= 7; index++)
		bloom[0] += bloom[index];
	
	bloom[0] /= 7.0;
#endif
	
	return bloom;
}

void Vignette(io vec3 color) {
	float edge = distance(texcoord, vec2(0.5));
	
	color *= 1.0 - pow(edge * 1.3, 1.5);
}

void Tonemap(io vec3 color) {
	color *= EXPOSURE;
	color  = color / (color + 1.0);
	color  = pow(color, vec3(1.15 / 2.2));
}

void main() {
	float depth = GetDepth(texcoord);
	vec3  color = GetColor(texcoord);
	Mask  mask  = CalculateMasks(texture2D(colortex2, texcoord).r);
	
	MotionBlur(color, depth, mask.hand);
	
	vec3[8] bloom = GetBloom();
	
	color  = mix(color, min(pow(bloom[0], vec3(BLOOM_CURVE)), bloom[0]), BLOOM_AMOUNT);
	
	Vignette(color);
	Tonemap(color);
	
	gl_FragColor = vec4(color, 1.0);
	
	exit();
}
