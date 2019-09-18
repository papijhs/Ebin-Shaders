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

void MotionBlur(io vec3 color, float depth, float handMask) {
#ifdef MOTION_BLUR
	if (handMask > 0.5) return;
	
	vec3 position = vec3(texcoord, depth) * 2.0 - 1.0; // Signed [-1.0 to 1.0] screen space position
	
	vec3 previousPos    = CalculateViewSpacePosition(position);
	     previousPos    = transMAD(gbufferModelViewInverse, previousPos);
	     previousPos   += cameraPosition - previousCameraPosition;
	     previousPos    = transMAD(gbufferPreviousModelView, previousPos);
	     previousPos.xy = projMAD(projMatrix, previousPos).xy / -previousPos.z;
	
	cfloat intensity = MOTION_BLUR_INTENSITY * 0.5;
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
		
		color += pow2(texture2D(colortex3, clampScreen(coord, pixelSize)).rgb);
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

void GetBloom(io vec3 color) {
#ifdef BLOOM_ENABLED
	vec3[8] bloom;
	
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
	
	color = mix(color, min(pow(bloom[0], vec3(BLOOM_CURVE)), bloom[0]), BLOOM_AMOUNT);
#endif
}

void Vignette(io vec3 color) {
	float edge = distance(texcoord, vec2(0.5));
	
	color *= 1.0 - pow(edge * 1.3, 1.5);
}

#define TONEMAP 1 // [1 2 3]

void ReinhardTonemap(io vec3 color) {
	color *= EXPOSURE * 16.0;
	color  = color / (color + 1.0);
	color  = pow(color, vec3(1.15 / 2.2));
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
	color = pow(color, vec3(1.0 / 2.2));
}

void Tonemap(io vec3 color) {
#if TONEMAP == 1
	ReinhardTonemap(color);
#elif TONEMAP == 2
//	color = pow(color, vec3(1.0 / 1.5)) / 3.0 * 0.25;
	
	BurgessTonemap(color);
#else
	Uncharted2Tonemap(color);
#endif
}

/* DRAWBUFFERS:1 */
#include "/lib/Exit.glsl"

void main() {
	float depth = GetDepth(texcoord);
	vec3  color = GetColor(texcoord);
	Mask  mask  = CalculateMasks(texture2D(colortex2, texcoord).r);
	
	MotionBlur(color, depth, mask.hand);
	
	GetBloom(color); 
	
//	Vignette(color);
	Tonemap(color);
	
	gl_FragColor = vec4(color, 1.0);
	
	exit();
}
