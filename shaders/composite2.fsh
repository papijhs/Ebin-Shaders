#version 410 compatibility
#define composite2
#define fsh
#define ShaderStage 2
#include "/lib/Syntax.glsl"

/* DRAWBUFFERS:32 */

const bool colortex5MipmapEnabled = true;

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

flat varying vec2 pixelSize;

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

vec2 ViewSpaceToScreenSpace(vec3 viewSpacePosition) {
	return (diagonal2(projMatrix) * viewSpacePosition.xy + projMatrix[3].xy) / -viewSpacePosition.z * 0.5 + 0.5;
}

#include "/lib/Fragment/Sky.fsh"

int GetMaxSteps(vec3 pos, vec3 ray, float maxRayDepth, float rayGrowth) { // Returns the number of steps until the ray goes offscreen, or past maxRayDepth
	vec4 c =  vec4(diagonal2(projMatrix) * pos.xy + projMatrix[3].xy, diagonal2(projMatrix) * ray.xy);
	     c = -vec4((c.xy - pos.z) / (c.zw - ray.z), (c.xy + pos.z) / (c.zw + ray.z)); // Solve for (M*(pos + ray*c) + A) / (pos.z + ray.z*c) = +-1.0
	
	c = mix(c, vec4(1000000.0), lessThan(c, vec4(0.0))); // Remove negative coefficients from consideration by making them B I G
	
	float x = minVec4(c); // Nearest ray length to reach screen edge
	
	if (ray.z < 0.0) // If stepping away from player
		x = min(x, (maxRayDepth + pos.z) / -ray.z); // Clip against maxRayDepth
	
	x = (log2(1.0 - x*(1.0 - rayGrowth))) / log2(rayGrowth); // Solve geometric sequence with  a = 1.0  and  r = rayGrowth
	
	return min(75, int(x));
}

bool ComputeRaytracedIntersection(vec3 vPos, vec3 dir, out vec3 screenPos) {
	cfloat rayGrowth      = 1.15;
	cfloat rayGrowthL2    = log2(rayGrowth);
	cint   maxRefinements = 0;
	cbool  doRefinements  = maxRefinements != 0;
	float  maxRayDepth    = far * 1.75;
	int    maxSteps       = GetMaxSteps(vPos, dir, maxRayDepth, rayGrowth);
	
	vec3 rayStep = dir;
	vec3 ray = vPos + rayStep;
	
	float refinements = 0.0;
	
	vec2 zMAD = -vec2(projInverseMatrix[2][3] * 2.0, projInverseMatrix[3][3] - projInverseMatrix[2][3]);
	
	for (int i = 0; i < maxSteps; i++) {
		screenPos.st = ViewSpaceToScreenSpace(ray);
		
	//	if (any(greaterThan(abs(screenPos.st - 0.5), vec2(0.5))) || -ray.z > maxRayDepth) return false;
		
		screenPos.z = texture2D(depthtex1, screenPos.st).x;
		
		float depth = screenPos.z * zMAD.x + zMAD.y;
		
		if (ray.z * depth >= 1.0) { // if (1.0 / (depth * a + b) >= ray.z), quick way to compare ray with hyperbolic sample depth without doing a division
			float diff = (1.0 / depth) - ray.z;
			
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
	
	float alpha = pow2(clamp01(1.0 + dotNorm(position[0], normal))) * smoothness;
	
	if (length(alpha) < 0.0005) return;
	
	
	mat2x3 refRay;
	refRay[0] = reflect(position[0], normal);
	refRay[1] = mat3(gbufferModelViewInverse) * refRay[0];
	
	vec3 refCoord;
	vec3 reflection;
	
	float sunlight = ComputeSunlight(position[1], GetLambertianShading(normal) * skyLightmap);
	
	float fogFactor = 1.0;
	
	bool hit = ComputeRaytracedIntersection(position[0], normalize(refRay[0]), refCoord);
	
	if (hit) {
		reflection = GetColor(refCoord.st);
		
		vec3 refVPos = CalculateViewSpacePosition(refCoord);
		
		fogFactor = CalculateFogFactor(refVPos, FOG_POWER, 0.0);
		
		#ifdef REFLECTION_EDGE_FALLOFF
			float angleCoeff = clamp01(pow(normal.z + 0.15, 0.25) * 2.0) * 0.2 + 0.8;
			float dist       = length8(abs(refCoord.st - vec2(0.5)));
			float edge       = clamp01(1.0 - pow2(dist * 2.0 * angleCoeff));
			fogFactor        = clamp01(fogFactor + pow(1.0 - edge, 10.0));
		#endif
	}
	
	vec3 reflectedSky = CalculateSky(refRay[1], position[1], float(!hit), fogFactor, true, sunlight);
	
	reflection = mix(reflection, reflectedSky, fogFactor);
	
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
	
	#define VolCloudLOD 0 // [0 1 2]
	
	vec4 cloud = textureLod(colortex5, texcoord, VolCloudLOD);
	
	cloud.rgb = pow2(cloud.rgb) * 50.0;
	
	vec3 sky = CalculateSky(backPos[1], vec3(0.0), float(depth1 >= 1.0), 1.0 - alpha, false, 1.0);
	
	sky = mix(sky, cloud.rgb, cloud.a);
	
	vec3 normal = DecodeNormal(texture4.g, 11) * mat3(gbufferModelViewInverse);
	
	if (isEyeInWater == 1) sky = WaterFog(sky, normal, frontPos[0], vec3(0.0));
	else if (mask.water > 0.5) sky = mix(WaterFog(sky, normal, frontPos[0], backPos[0]), sky, CalculateFogFactor(frontPos[0], FOG_POWER));
	
	if (depth0 >= 1.0) { gl_FragData[0] = vec4(EncodeColor(sky), 1.0); exit(); return; }
	
	
	vec3 color0 = vec3(0.0);
	vec3 color1 = texture2D(colortex1, texcoord).rgb;
	
	if (mask.transparent > 0.5)
		color0 = texture2D(colortex3, texcoord).rgb / alpha;
	
	if (mask.transparent > 0.5) 
		color1 = mix(color1, sky.rgb, CalculateFogFactor(backPos[0], FOG_POWER, float(depth1 >= 1.0))) ;// * (1.0 - float(mask.water > 0.5 && isEyeInWater == 0)));
	
	if (mask.transparent - mask.water < 0.5)
		color0 = color1;
	
	ComputeReflectedLight(color0, frontPos, normal, smoothness, skyLightmap);
	
	
	if (mask.transparent > 0.5)
		color0 += AerialPerspective(length(frontPos[0]), skyLightmap);
	
	if (depth1 >= 1.0)
		color0 = mix(sky.rgb, color0, mix(alpha, 0.0, isEyeInWater == 1));
	
	
	color0 = mix(color0, sky.rgb, CalculateFogFactor(frontPos[0], FOG_POWER));
	
	if (depth1 < 1.0 && mask.transparent > 0.5) color0 = mix(color1, color0, alpha);
	if (depth1 >= 1.0 && mask.water > 0.5 && isEyeInWater == 1) color0 = color1;
	
	gl_FragData[0] = vec4(clamp01(EncodeColor(color0)), 1.0);
	
	exit();
}
