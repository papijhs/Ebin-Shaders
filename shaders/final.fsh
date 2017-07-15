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
uniform float rainStrength;

uniform int isEyeInWater;

varying vec2 texcoord;

flat varying vec2 pixelSize;

#include "/lib/Settings.glsl"
#include "/lib/Utility.glsl"
#include "/lib/Debug.glsl"
#include "/lib/Uniform/Projection_Matrices.fsh"
#include "/lib/Uniform/Shading_Variables.glsl"
#include "/lib/Uniform/Shadow_View_Matrix.fsh"
#include "/lib/Fragment/Masks.fsh"

vec3 GetColor(vec2 coord) {
	return DecodeColor(texture2D(colortex3, coord).rgb);
}

float GetDepth(vec2 coord) {
	return texture2D(gdepthtex, coord).x;
}

vec3 CalculateViewSpacePosition(vec3 screenPos) {
	return projMAD(projInverseMatrix, screenPos) / (screenPos.z * projInverseMatrix[2].w + projInverseMatrix[3].w);
}

vec3 ViewSpaceToScreenSpace(vec3 viewSpacePosition) {
	return projMAD(projMatrix, viewSpacePosition) / -viewSpacePosition.z;
}

//#define MOTION_BLUR
#define VARIABLE_MOTION_BLUR_SAMPLES
#define MAX_MOTION_BLUR_SAMPLE_COUNT            50    // [10 25 50 100]
#define VARIABLE_MOTION_BLUR_SAMPLE_COEFFICIENT 1.000 // [0.125 0.250 0.500 1.000]
#define CONSTANT_MOTION_BLUR_SAMPLE_COUNT       2     // [2 3 4 5 10]
#define MOTION_BLUR_INTENSITY                   1.0   // [0.5 1.0 2.0]
#define MAX_MOTION_BLUR_AMOUNT                  1.0   // [0.5 1.0 2.0]

void MotionBlur(io vec3 color, float depth, float handMask) {
#ifndef MOTION_BLUR
	return;
#endif
	
	if (handMask > 0.5) return;
	
	vec3 position = vec3(texcoord, depth) * 2.0 - 1.0; // Signed [-1.0 to 1.0] screen space position
	
	vec3 previousPos    = CalculateViewSpacePosition(position);
	     previousPos    = transMAD(gbufferModelViewInverse, previousPos);
	     previousPos   += cameraPosition - previousCameraPosition;
	     previousPos    = transMAD(gbufferPreviousModelView, previousPos);
	     previousPos.xy = projMAD(projMatrix, previousPos).xy / -previousPos.z;
	
	cfloat intensity   = MOTION_BLUR_INTENSITY  * 0.5;
	cfloat maxVelocity = MAX_MOTION_BLUR_AMOUNT * 0.1;
	
	vec2 velocity = (position.st - previousPos.st) * intensity; // Screen-space motion vector
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
		
		color += DecodeColor(texture2D(colortex3, clampScreen(coord, pixelSize)).rgb);
	}
	
	color /= max(sampleCount + 1.0, 1.0);
}

#include "/lib/Misc/BicubicTexture3.glsl"

#define BLOOM_ENABLED
#define BLOOM_AMOUNT     0.20 // [0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00]
#define BLOOM_BRIGHTNESS 1.0  // [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.1 2.2 2.3 2.4 2.5 2.6 2.7 2.8 2.9 3.0 3.1 3.2 3.3 3.4 3.5 3.6 3.7 3.8 3.9 4.0]

vec3 SeishinBloomTile(cfloat lod, vec2 offset) {
	return DecodeColor(BicubicTexture(colortex1, texcoord / exp2(lod) + offset));
}

void SeishinBloom(inout vec3 color) {
#ifndef BLOOM_ENABLED
	return;
#endif
	
	vec3 bloom = vec3(0.0);
	bloom += SeishinBloomTile(2.0, vec2(0.0                         ,                        0.0)) * 1.00;
	bloom += SeishinBloomTile(3.0, vec2(0.0                         , 0.25   + pixelSize.y * 2.0)) * 1.28;
	bloom += SeishinBloomTile(4.0, vec2(0.125    + pixelSize.x * 2.0, 0.25   + pixelSize.y * 2.0)) * 2.00;
	bloom += SeishinBloomTile(5.0, vec2(0.1875   + pixelSize.x * 4.0, 0.25   + pixelSize.y * 2.0)) * 3.92;
	bloom += SeishinBloomTile(6.0, vec2(0.125    + pixelSize.x * 2.0, 0.3125 + pixelSize.y * 4.0)) * 4.80;
	bloom += SeishinBloomTile(7.0, vec2(0.140625 + pixelSize.x * 4.0, 0.3125 + pixelSize.y * 4.0)) * 5.38;
	
	bloom *= 0.0355 * BLOOM_BRIGHTNESS;
	
	float amount = BLOOM_AMOUNT;
	
	if (isEyeInWater == 1) {
	//	bloom *= 8.0;
		amount = mix(amount, 1.0, 0.5);
	}
	
	color = mix(color, bloom, amount);
}

void Vignette(io vec3 color) {
	float edge = distance(texcoord, vec2(0.5));
	
	color *= 1.0 - pow(edge * 1.3, 1.5);
}

#define TONEMAP 1 // [1 2 3]

#define EXPOSURE   1.0 // [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.1 2.2 2.3 2.4 2.5 2.6 2.7 2.8 2.9 3.0 3.1 3.2 3.3 3.4 3.5 3.6 3.7 3.8 3.9 4.0]
#define SATURATION 1.0 // [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]

void ReinhardTonemap(io vec3 color) {
	color *= EXPOSURE * 16.0;
	color  = color / (color + 1.0);
	color  = powf(color, 1.0 / 2.2);
	
	color = rgb(hsv(color) * vec3(1.0, SATURATION, 1.0));
}

vec3 Curve(vec3 x, vec3 a, vec3 b, vec3 c, vec3 d, vec3 e) {
	x *= max0(a);
	x  = ((x * (c * x + 0.5)) / (x * (c * x + 1.7) + b)) + e;
	x  = pow(x, d);
	
	return x;
}

void BurgessTonemap(io vec3 color) {
	vec3  a, b, c, d, e, f;
	float g;
	
	#define BURGESS_PRESET 1 // [1 2 3 4]
	
#if BURGESS_PRESET == 1 // Default
	a =  3.00 * vec3(1.0, 1.0, 1.0); // Exposure
	b =  1.00 * vec3(1.0, 1.0, 1.0); // Contrast
	c = 12.00 * vec3(1.0, 1.0, 1.0); // Vibrance
	d =  0.42 * vec3(1.0, 1.0, 1.0); // Gamma
	e =  0.00 * vec3(1.0, 1.0, 1.0); // Lift
	f =  1.00 * vec3(1.0, 1.0, 1.0); // Highlights
	g =  1.00; // Saturation
#elif BURGESS_PRESET == 2 // Silvia's Ebin preset
	a =  1.50 * vec3(1.00, 1.06, 0.93); // Exposure
	b =  0.60 * vec3(1.00, 1.00, 0.91); // Contrast
	c = 17.00 * vec3(1.00, 1.00, 0.70); // Vibrance
	d =  0.46 * vec3(0.93, 1.00, 1.00); // Gamma
	e =  0.01 * vec3(1.50, 1.00, 1.00); // Lift
	f =  1.00 * vec3(1.00, 1.00, 1.00); // Highlights
	g =  0.93; // Saturation
	
	e *= smoothstep(0.1, -0.1, worldLightVector.y);
#elif BURGESS_PRESET == 3 // Silvia's preferred from continuity
	a =  1.60 * vec3(0.94, 1.00, 1.00); // Exposure
	b =  0.60 * vec3(1.00, 1.00, 1.00); // Contrast
	c = 12.00 * vec3(1.00, 1.00, 1.00); // Vibrance
	d =  0.36 * vec3(0.92, 1.00, 1.00); // Gamma
	e =  0.00 * vec3(1.00, 1.00, 1.00); // Lift
	f =  1.00 * vec3(1.00, 1.00, 1.00); // Highlights
	g = 1.09; // Saturation
#else
	/*
	 * Tweak custom Burgess tonemap HERE
	 */
	a = vec3(1.5, 1.6, 1.6);	//Exposure
	b = vec3(0.6, 0.6, 0.6);	//Contrast
	c = vec3(12.0, 12.0, 12.0);	//Vibrance
	d = vec3(0.33, 0.36, 0.36);	//Gamma
	e = vec3(0.000, 0.000, 0.000);	//Lift
	f = vec3(1.05, 1.02, 1.0);    //Highlights
	g = 1.19;                    //Saturation
#endif
	
//	e *= smoothstep(0.1, -0.1, worldLightVector.y);
//	g *= 1.0 - rainStrength * 0.5;
	
	a *= EXPOSURE;
	g *= SATURATION;
	
	color = Curve(color, a, b, c, d, e);
	
	float luma = dot(color, lumaCoeff);
	color  = mix(vec3(luma), color, g) / Curve(vec3(1.0), a, b, c, d, e);
	color *= f;
}

void Uncharted2Tonemap(io vec3 color) {
	cfloat A = 0.15, B = 0.5, C = 0.1, D = 0.2, E = 0.02, F = 0.3, W = 11.2;
	cfloat whiteScale = 1.0 / (((W * (A * W + C * B) + D * E) / (W * (A * W + B) + D * F)) - E / F);
	cfloat ExposureBias = 2.3 * EXPOSURE;
	
	vec3 curr = ExposureBias * color;
	     curr = ((curr * (A * curr + C * B) + D * E) / (curr * (A * curr + B) + D * F)) - E / F;
	
	color = curr * whiteScale;
	color = powf(color, 1.0 / 2.2);
}

void Tonemap(io vec3 color) {
#if TONEMAP == 1
	ReinhardTonemap(color);
#elif TONEMAP == 2
	BurgessTonemap(color);
#else
	Uncharted2Tonemap(color);
#endif
}

void main() {
	float depth = GetDepth(texcoord);
	vec3  color = GetColor(texcoord);
	Mask  mask  = CalculateMasks(texture2D(colortex2, texcoord).r);
	
	MotionBlur(color, depth, mask.hand);
	SeishinBloom(color); 
//	Vignette(color);
	Tonemap(color);
	
	gl_FragColor = vec4(color, 1.0);
	
	exit();
}
