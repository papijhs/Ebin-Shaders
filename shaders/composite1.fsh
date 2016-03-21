#version 120

const bool colortex4MipmapEnabled = true;

uniform sampler2D colortex0;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler2D colortex5;
uniform sampler2D gdepthtex;
uniform sampler2D shadowcolor;
uniform sampler2DShadow shadow;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;
uniform mat4 shadowModelViewInverse;

uniform vec3 cameraPosition;

uniform float viewWidth;
uniform float viewHeight;

uniform float far;

varying vec2 texcoord;

#include "/lib/Settings.txt"
#include "/lib/PostHeader.fsh"
#include "/lib/GlobalCompositeVariables.fsh"
#include "/lib/Masks.glsl"
#include "/lib/ShadingStructs.fsh"
#include "/lib/ShadingFunctions.fsh"
#include "/lib/CalculateFogFactor.glsl"


vec3 DecodeColor(in vec3 color) {
	return pow(color, vec3(2.2)) * 1000.0;
}

vec3 EncodeColor(in vec3 color) {    // Prepares the color to be sent through a limited dynamic range pipeline
	return pow(color * 0.001, vec3(1.0 / 2.2));
}

vec3 GetDiffuse(in vec2 coord) {
	return texture2D(colortex2, coord).rgb;
}

vec3 DecodeNormal(vec2 encodedNormal) {
	encodedNormal = encodedNormal * 2.0 - 1.0;
    vec2 fenc = encodedNormal * 4.0 - 2.0;
	float f = dot(fenc, fenc);
	float g = sqrt(1.0 - f / 4.0);
	return vec3(fenc * g, 1.0 - f / 2.0);
}

vec3 GetNormal(in vec2 coord) {
	return DecodeNormal(texture2D(colortex0, coord).xy);
}

float GetDepth(in vec2 coord) {
	return texture2D(gdepthtex, coord).x;
}

vec4 CalculateViewSpacePosition(in vec2 coord, in float depth) {
	vec4 position  = gbufferProjectionInverse * vec4(vec3(coord, depth) * 2.0 - 1.0, 1.0);
	     position /= position.w;
	
	return position;
}

vec3 GetIndirectLight(in vec2 coord) {
	return DecodeColor(texture2D(colortex4, coord).rgb);
}

float GetVolLight(in vec2 coord) {
	return texture2D(colortex5, coord).r;
}

vec3 CalculateSkyGradient(in vec4 viewSpacePosition) {
	float radius = max(176.0, far * sqrt(2.0));
	const float horizonLevel = 64.0;
	
	vec3 worldPosition = (gbufferModelViewInverse * vec4(normalize(viewSpacePosition.xyz), 0.0)).xyz;
	     worldPosition.y = radius * worldPosition.y / length(worldPosition.xz) + cameraPosition.y - horizonLevel;
	     worldPosition.xz = normalize(worldPosition.xz) * radius;
	
	float dotUP = dot(normalize(worldPosition), vec3(0.0, 1.0, 0.0));
	
	float horizonCoeff  = dotUP * 0.65;
	      horizonCoeff  = abs(horizonCoeff);
	      horizonCoeff  = pow(1.0 - horizonCoeff, 3.0) / 0.65 * 5.0 + 0.35;
	
	vec3 color = colorSkylight * horizonCoeff;
	
	return color;
}

vec4 CalculateSky(in vec4 viewSpacePosition, in Mask mask) {
	float fogFactor = max(CalculateFogFactor(viewSpacePosition, FOGPOW), mask.sky);
	vec3  gradient  = CalculateSkyGradient(viewSpacePosition);
	vec4  composite;
	
	
	composite.a   = fogFactor;
	composite.rgb = gradient;
	
	
	return vec4(composite);
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


void main() {
	Mask mask;
	CalculateMasks(mask, texture2D(colortex3, texcoord).b, true);
	
	vec3  diffuse           = (mask.sky < 0.5 ? GetDiffuse(texcoord) : vec3(0.0));    // Ternary statements avoid redundant texture lookups for sky pixels.
	vec3  normal            = (mask.sky < 0.5 ?  GetNormal(texcoord) : vec3(0.0));
	float depth             = (mask.sky < 0.5 ?   GetDepth(texcoord) : 1.0);
	
	vec4  viewSpacePosition = CalculateViewSpacePosition(texcoord, depth);
	
	#ifdef DEFERRED_SHADING
	float torchLightmap     = texture2D(colortex3, texcoord).r;
	float skyLightmap       = texture2D(colortex3, texcoord).g;
	
	vec3 composite = CalculateShadedFragment(diffuse, mask, torchLightmap, skyLightmap, normal, viewSpacePosition);
	
	vec3 final = composite;
	#else
	vec3 final = DecodeColor(diffuse);
	#endif
	
	final += GetIndirectLight(texcoord);
	
	vec4 sky = CalculateSky(viewSpacePosition, mask);
	
	float VL = GetVolLight(texcoord);
	
	final = mix(final, sky.rgb, min(1.0, (sky.a * VL) + pow(sky.a, 3)));// + sky.a * sky.a * sky.a * sky.a));
	
	gl_FragData[0] = vec4(Uncharted2Tonemap(final), 1.0);
}