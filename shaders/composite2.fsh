#version 410 compatibility
#define composite2
#define fsh
#define ShaderStage 2
#include "/lib/Syntax.glsl"

/* DRAWBUFFERS:32 */

const bool colortex1MipmapEnabled = true;

uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
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

float CalculateViewSpaceZ(float depth, vec2 mad) {
	return 1.0 / (depth * mad.x + mad.y);
}

vec2 ViewSpaceToScreenSpace(vec3 viewSpacePosition) {
	return (diagonal2(projMatrix) * viewSpacePosition.xy + projMatrix[3].xy) / -viewSpacePosition.z * 0.5 + 0.5;
}

#include "/lib/Fragment/Sky.fsh"

float ebin(vec3 p, vec3 r) {
	vec4 c = vec4(diagonal2(projMatrix)*p.xy + projMatrix[3].xy, diagonal2(projMatrix)*r.xy);
	
	c = -vec4((c.xy - p.z) / (c.zw - r.z), (c.xy + p.z) / (c.zw + r.z));
	
	c    = mix(c, vec4(1000000.0), lessThan(c, vec4(0.0)));
	c.xy = mix(c.zw, c.xy, lessThan(c.xy, c.zw));
	
	
	return min(c.x, c.y);
	
	/*
	vec2 a = -(diagonal2(projMatrix)*p.xy + projMatrix[3].xy - p.z) / (diagonal2(projMatrix)*r.xy - r.z);
	vec2 b = -(diagonal2(projMatrix)*p.xy + projMatrix[3].xy + p.z) / (diagonal2(projMatrix)*r.xy + r.z);
	
	a = mix(a, vec2(1000000.0), lessThan(a, vec2(0.0)));
	b = mix(b, vec2(1000000.0), lessThan(b, vec2(0.0)));
	
	return mix(b, a, lessThan(a, b));
	*/
}

bool ComputeRaytracedIntersection(vec3 vPos, vec3 dir, out vec3 screenSpacePosition) {
	cfloat rayGrowth = 1.25;
	cfloat rayGrowthL2 = log2(rayGrowth);
	cint maxRefinements = 0;
	int maxSteps = 30;
	
	
	float x = ebin(vPos, dir);
	
	if (dir.z < 0.0) {
		float maxRayDepth = far * 1.875;
		
		float f = (far * 1.875 - abs(vPos.z)) / abs(dir.z);
		
		x = min(x, f);
	}
	
	x = floor((log2(1.0 - x*(1.0 - rayGrowth))) / log2(rayGrowth));
	
	maxSteps = min(maxSteps, int(x));
	
	
	vec3 rayStep = dir;
	vec3 ray = vPos + rayStep;
	
	float refinements = 0.0;
	
	cbool doRefinements = (maxRefinements != 0);
	
	float maxRayDepth = -far * 1.875;
	
	vec2 zMAD = -vec2(projInverseMatrix[2][3] * 2.0, projInverseMatrix[3][3] - projInverseMatrix[2][3]);
	
	for (int i = 0; i < maxSteps; i++) {
		screenSpacePosition.xy = ViewSpaceToScreenSpace(ray);
		
	//	if (any(greaterThan(abs(screenSpacePosition.xy - 0.5), vec2(0.5))) || ray.z < maxRayDepth) return false;
		
		screenSpacePosition.z = texture2D(depthtex1, screenSpacePosition.st).x;
		
		float adjDepth = screenSpacePosition.z * zMAD.x + zMAD.y;
		
		if (ray.z * adjDepth >= 1.0) { // if (1.0 / (depth * a + b) >= ray.z)
			float diff = (1.0 / adjDepth) - ray.z;
			
			if (doRefinements) {
				float error = exp2(i * rayGrowthL2 + refinements); // length(rayStep) * exp2(refinements)
				
				if (refinements <= maxRefinements && diff <= error * 2.0) {
					rayStep *= 0.5;
					ray -= rayStep;
					refinements++;
					continue;
				} else if (refinements > maxRefinements && diff <= error * 4.0) {
					return true;
				}
			} else return (diff <= exp2(i * rayGrowthL2 + 1.0));
		}
		
		ray += rayStep;
		
		rayStep *= rayGrowth;
	}
	
	return false;
}

#include "lib/Fragment/Water_Depth_Fog.fsh"
#include "/lib/Fragment/AerialPerspective.fsh"

#include "/lib/Misc/Bias_Functions.glsl"
#include "/lib/Fragment/Sunlight_Shading.fsh"

void ComputeReflectedLight(io vec3 color, mat2x3 position, vec3 normal, float smoothness, float skyLightmap) {
	if (isEyeInWater == 1) return;
	
	float alpha = pow2(clamp01(1.0 + dot(normalize(position[0]), normal))) * smoothness;
	
	if (length(alpha) < 0.0005) return;
	
	mat2x3 refRay;
	refRay[0] = reflect(position[0], normal);
	refRay[1] = mat3(gbufferModelViewInverse) * refRay[0];
	
	vec3  reflectedCoord;
	vec3  reflection;
	
	float sunlight = ComputeSunlight(position[1], GetLambertianShading(normal) * skyLightmap);
	
	vec3 reflectedSky = CalculateSky(refRay[1], position[1], 1.0, 1.0, true, sunlight);
	
	vec3 offscreen = reflectedSky * skyLightmap;
	
	if (!ComputeRaytracedIntersection(position[0], normalize(refRay[0]), reflectedCoord))
		reflection = offscreen;
	else {
		reflection = GetColor(reflectedCoord.st);
		
		vec3 refViewSpacePosition = CalculateViewSpacePosition(reflectedCoord);
		
	//	#define DOUBLE_WATER_REFLECTIONS
		#ifdef DOUBLE_WATER_REFLECTIONS
			vec2 texture4 = textureRaw(colortex4, reflectedCoord.st).rg;
			Mask mask     = CalculateMasks(Decode4x8F(texture4.r).r);
			
			if (mask.water > 0.5) {
				vec3 normal2 = DecodeNormal(texture4.g, 11) * mat3(gbufferModelViewInverse);
				
				refRay[0] = reflect(refViewSpacePosition, normal2);
				refRay[1] = mat3(gbufferModelViewInverse) * refRay[0];
				
			//	reflection = mix(reflection, CalculateSky(refRay[1], mat3(gbufferModelViewInverse) * refViewSpacePosition, 1.0, 1.0, true, 1.0) + AerialPerspective(length(abs(refViewSpacePosition) + abs(position[0])), 1.0)*1.0, pow2(clamp01(1.0 + dot(normalize(refViewSpacePosition - position[0]), normal2))));
				reflection = offscreen;
			}
		#endif
		
		reflection = mix(reflection, reflectedSky, CalculateFogFactor(refViewSpacePosition, FOG_POWER));
		
		#ifdef REFLECTION_EDGE_FALLOFF
			float angleCoeff = clamp01(pow(normal.z + 0.15, 0.25) * 2.0) * 0.2 + 0.8;
			float dist       = length8(abs(reflectedCoord.xy - vec2(0.5)));
			float edge       = clamp01(1.0 - pow2(dist * 2.0 * angleCoeff));
			reflection       = mix(reflection, offscreen, pow(1.0 - edge, 10.0));
		#endif
	}
	
	color = mix(color, reflection, alpha);
}

void main() {
	vec2 texture4 = ScreenTex(colortex4).rg;
	
	vec4  decode4       = Decode4x8F(texture4.r);
	Mask  mask          = CalculateMasks(decode4.r);
	float smoothness    = decode4.g;
	float skyLightmap   = decode4.a;
	
	gl_FragData[1] = vec4(decode4.r, 0.0, 0.0, 1.0);
	
	float depth0 = (mask.hand > 0.5 ? 0.55 : GetDepth(texcoord));
	
	mat2x3 frontPos;
	frontPos[0] = CalculateViewSpacePosition(vec3(texcoord, depth0));
	frontPos[1] = mat3(gbufferModelViewInverse) * frontPos[0];
	
	float  depth1  = depth0;
	mat2x3 backPos = frontPos;
	float  alpha   = 0.0;
	
	if (mask.transparent > 0.5) {
		depth1 = (mask.hand > 0.5 ? 0.55 : GetTransparentDepth(texcoord));
		
		backPos[0] = CalculateViewSpacePosition(vec3(texcoord, depth1));
		backPos[1] = mat3(gbufferModelViewInverse) * backPos[0];
		
		alpha = texture2D(colortex2, texcoord).r;
	}
	
	vec3 sky = CalculateSky(backPos[1], vec3(0.0), float(depth1 >= 1.0), 1.0 - alpha, false, 1.0);
	
	vec3 normal = DecodeNormal(texture4.g, 11) * mat3(gbufferModelViewInverse);
	
	if (isEyeInWater == 1) sky = WaterFog(sky, normal, frontPos[0], vec3(0.0));
	else if (mask.water > 0.5) sky = mix(WaterFog(sky, normal, frontPos[0], backPos[0]), sky, CalculateFogFactor(frontPos[0], FOG_POWER));
	
	if (depth0 >= 1.0) { gl_FragData[0] = vec4(EncodeColor(sky), 1.0); exit(); return; }
	
	vec3 color0 = vec3(0.0);
	vec3 color1 = vec3(0.0);
	
	if (mask.transparent > 0.5)
		color0 = texture2D(colortex3, texcoord).rgb / alpha;
	
	color1 = texture2D(colortex1, texcoord).rgb;
	
	if (mask.transparent > 0.5) 
		color1 = mix(color1, sky.rgb, CalculateFogFactor(backPos[0], FOG_POWER, float(depth1 >= 1.0))) ;// * (1.0 - float(mask.water > 0.5 && isEyeInWater == 0)));
	
	color0 = mix(color1, color0, mask.transparent - mask.water);
	
	ComputeReflectedLight(color0, frontPos, normal, smoothness, skyLightmap);
	
	
	if (mask.transparent > 0.5)
		color0 += AerialPerspective(length(frontPos[0]), skyLightmap);
	
	if (depth1 >= 1.0)
		color0 = mix(sky.rgb, color0, mix(alpha, 0.0, isEyeInWater == 1));
	
	
	color0 = mix(color0, sky.rgb, CalculateFogFactor(frontPos[0], FOG_POWER));
	
	if (depth1 < 1.0 && mask.transparent > 0.5) color0 = mix(color1, color0, alpha);
	if (depth1 >= 1.0 && mask.water > 0.5 && isEyeInWater == 1) color0 = color1;
	
	gl_FragData[0] = vec4(EncodeColor(color0), 1.0);
	
	exit();
}
