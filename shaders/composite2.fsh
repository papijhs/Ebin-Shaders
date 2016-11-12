#version 410 compatibility
#define composite2
#define fsh
#define ShaderStage 2
#include "/lib/Syntax.glsl"

/* DRAWBUFFERS:3 */

const bool colortex1MipmapEnabled = true;

uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler2D colortex5;
uniform sampler2D gdepthtex;
uniform sampler2D depthtex1;
uniform sampler2D noisetex;
uniform sampler2DShadow shadow; 

uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowProjection;

uniform vec3 cameraPosition;

uniform float frameTimeCounter;
uniform float rainStrength;

uniform float viewWidth;
uniform float viewHeight;

uniform float near;
uniform float far;

uniform ivec2 eyeBrightnessSmooth;

uniform int isEyeInWater;

varying vec2 texcoord;
varying vec2 pixelSize;

#include "/lib/Settings.glsl"
#include "/lib/Utility.glsl"
#include "/lib/Debug.glsl"
#include "/lib/Uniform/Projection_Matrices.fsh"
#include "/lib/Uniform/Shading_Variables.glsl"
#include "/lib/Uniform/Shadow_View_Matrix.fsh"
#include "/lib/Fragment/Masks.fsh"
#include "/lib/Misc/Calculate_Fogfactor.glsl"


vec3 GetColor(vec2 coord) {
	return texture2D(colortex1, coord).rgb;
}

float GetDepth(vec2 coord) {
	return texture2D(gdepthtex, coord).x;
}

float GetTransparentDepth(vec2 coord) {
	return texture2D(depthtex1, coord).x;
}

vec3 CalculateViewSpacePosition(vec3 screenPos) {
	screenPos = screenPos * 2.0 - 1.0;
	
	return projMAD(projInverseMatrix, screenPos) / (screenPos.z * projInverseMatrix[2].w + projInverseMatrix[3].w);
}

vec3 ViewSpaceToScreenSpace(vec3 viewSpacePosition) {
	return projMAD(projMatrix, viewSpacePosition) / -viewSpacePosition.z * 0.5 + 0.5;
}


#include "/lib/Fragment/Sky.fsh"

bool ComputeRaytracedIntersection(vec3 startingViewPosition, vec3 rayDirection, float firstStepSize, cfloat rayGrowth, cint maxSteps, cint maxRefinements, out vec3 screenSpacePosition, out vec3 viewSpacePosition) {
	vec3 rayStep = rayDirection * firstStepSize;
	vec3 ray = startingViewPosition + rayStep;
	
	screenSpacePosition = ViewSpaceToScreenSpace(ray);
	
	float refinements = 0.0;
	float refinementCoeff = 1.0;
	
	cbool doRefinements = (maxRefinements > 0);
	
	float maxRayDepth = -far * 1.875;
	
	for (int i = 0; i < maxSteps; i++) {
		if (any(greaterThan(abs(screenSpacePosition.xyz - 0.5), vec3(0.5))) || ray.z < maxRayDepth)
			return false;
		
		float sampleDepth = GetTransparentDepth(screenSpacePosition.st);
		
		viewSpacePosition = CalculateViewSpacePosition(vec3(screenSpacePosition.st, sampleDepth));
		
		float diff = viewSpacePosition.z - ray.z;
		
		if (diff >= 0.0) {
			if (doRefinements) {
				float error = firstStepSize * pow(rayGrowth, i) * refinementCoeff;
				
				if(diff <= error * 2.0 && refinements <= maxRefinements) {
					ray -= rayStep * refinementCoeff;
					refinements += 1.0;
					refinementCoeff = exp2(-refinements);
				} else if (diff <= error * 4.0 && refinements > maxRefinements) {
					screenSpacePosition.z = sampleDepth;
					return true;
				}
			}
			
			else return true;
		}
		
		ray += rayStep * refinementCoeff;
		
		rayStep *= rayGrowth;
		
		screenSpacePosition = ViewSpaceToScreenSpace(ray);
	}
	
	return false;
}

#include "/lib/Misc/Bias_Functions.glsl"
#include "/lib/Fragment/Sunlight_Shading.fsh"

void ComputeReflectedLight(inout vec3 color, mat2x3 position, vec3 normal, float smoothness, float skyLightmap) {
	if (isEyeInWater == 1) return;
	
	float alpha = (pow2(min1(1.0 + dot(normalize(position[0]), normal))) * 0.99 + 0.01) * smoothness;
	
	if (length(alpha) < 0.005) return;
	
	mat2x3 refRay;
	refRay[0] = reflect(position[0], normal);
	refRay[1] = mat3(gbufferModelViewInverse) * refRay[0];
	
	float firstStepSize = mix(1.0, 30.0, pow2(length(position[1].xz) / 144.0));
	vec3  reflectedCoord;
	vec3  reflectedViewSpacePosition;
	vec3  reflection;
	
	float sunlight = ComputeSunlight(position[1], GetLambertianShading(normal) * skyLightmap, vec3(0.0));
	
	vec3 reflectedSky = CalculateSky(refRay[1], position[1], 1.0, 1.0, true, sunlight);
	
	vec3 offscreen = reflectedSky * skyLightmap;
	
	if (!ComputeRaytracedIntersection(position[0], normalize(refRay[0]), firstStepSize, 1.4, 30, 2, reflectedCoord, reflectedViewSpacePosition))
		reflection = offscreen;
	else {
		reflection = GetColor(reflectedCoord.st);
		
		reflection = mix(reflection, reflectedSky, CalculateFogFactor(reflectedViewSpacePosition, FOG_POWER));
		
		#ifdef REFLECTION_EDGE_FALLOFF
			float angleCoeff = clamp01(pow(normal.z + 0.15, 0.25) * 2.0) * 0.2 + 0.8;
			float dist       = length8(abs(reflectedCoord.xy - vec2(0.5)));
			float edge       = clamp01(1.0 - pow2(dist * 2.0 * angleCoeff));
			reflection       = mix(reflection, offscreen, pow(1.0 - edge, 10.0));
		#endif
	}
	
	color = mix(color, reflection, alpha);
}

#include "lib/Fragment/Water_Depth_Fog.fsh"

void main() {
	float depth0 = GetDepth(texcoord);
	
	mat2x3 frontPos;
	frontPos[0] = CalculateViewSpacePosition(vec3(texcoord, depth0));
	frontPos[1] = mat3(gbufferModelViewInverse) * frontPos[0];
	
	
	vec2 texure4 = ScreenTex(colortex4).rg;
	
	vec4  decode4       = Decode4x8F(texure4.r);
	Mask  mask          = CalculateMasks(decode4.r);
	float smoothness    = decode4.g;
	float skyLightmap   = decode4.a;
	
	float  depth1  = depth0;
	mat2x3 backPos = frontPos;
	float  alpha   = 0.0;
	
	if (mask.transparent > 0.5) {
		depth1 = (mask.hand > 0.5 ? depth0 : GetTransparentDepth(texcoord));
		
		backPos[0] = CalculateViewSpacePosition(vec3(texcoord, depth1));
		backPos[1] = mat3(gbufferModelViewInverse) * backPos[0];
		
		alpha = texture2D(colortex2, texcoord).r;
	}
	
	vec3 sky = CalculateSky(backPos[1], vec3(0.0), float(depth1 >= 1.0), 1.0 - alpha, false, 1.0);
	
	if (isEyeInWater == 1) sky = WaterFog(sky, frontPos[0], vec3(0.0));
	
	if (depth0 >= 1.0) { gl_FragData[0] = vec4(EncodeColor(sky), 1.0); exit(); return; }
	
	
	vec3 normal = DecodeNormal(texure4.g, 11) * mat3(gbufferModelViewInverse);
	
	vec3 color0 = vec3(0.0);
	vec3 color1 = vec3(0.0);
	
	if (mask.transparent > 0.5)
		color0 = texture2D(colortex3, texcoord).rgb / alpha;
	
	color1 = texture2D(colortex1, texcoord).rgb;
	color0 = mix(color1, color0, mask.transparent - mask.water);
	
	ComputeReflectedLight(color0, frontPos, normal, smoothness, skyLightmap);
	
	
	if (depth1 >= 1.0)
		color0 = mix(sky.rgb, color0, mix(alpha, 0.0, isEyeInWater == 1));
	
	
	color0 = mix(color0, sky.rgb, CalculateFogFactor(frontPos[0], FOG_POWER));
	color1 = mix(color1, sky.rgb, CalculateFogFactor(backPos[0], FOG_POWER));
	
	color0 += AerialPerspective(length(frontPos[0])) * float(depth1 < 1.0);
	color1 += AerialPerspective(length( backPos[0]));
	
	if (depth1 < 1.0 && mask.transparent > 0.5) color0 = mix(color1, color0, alpha);
	
	
	gl_FragData[0] = vec4(EncodeColor(color0), 1.0);
	
	exit();
}
