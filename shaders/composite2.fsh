#version 410 compatibility
#define composite2
#define fsh
#define ShaderStage 2
#include "/lib/Syntax.glsl"

/* DRAWBUFFERS:3 */

const bool colortex1MipmapEnabled = true;
const bool colortex6MipmapEnabled = true;

uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler2D colortex5;
uniform sampler2D colortex6;
uniform sampler2D gdepthtex;
uniform sampler2D depthtex1;
uniform sampler2D noisetex;
uniform sampler2DShadow shadow; 

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 shadowProjection;

uniform vec3 cameraPosition;

uniform float frameTimeCounter;
uniform float rainStrength;

uniform float viewWidth;
uniform float viewHeight;

uniform float near;
uniform float far;

uniform int isEyeInWater;

varying vec2 texcoord;
varying vec2 pixelSize;

#include "/lib/Settings.glsl"
#include "/lib/Utility.glsl"
#include "/lib/Debug.glsl"
#include "/lib/Uniform/Global_Composite_Variables.glsl"
#include "/lib/Fragment/Masks.fsh"
#include "/lib/Misc/Calculate_Fogfactor.glsl"


vec3 GetColor(vec2 coord) {
	return texture2D(colortex1, coord).rgb;
}

vec3 GetColorLod(vec2 coord, float lod) {
	return texture2DLod(colortex1, coord, lod).rgb;
}

float GetDepth(vec2 coord) {
	return texture2D(gdepthtex, coord).x;
}

float GetTransparentDepth(vec2 coord) {
	return texture2D(depthtex1, coord).x;
}

vec3 CalculateViewSpacePosition(vec3 screenPos) {
	screenPos = screenPos * 2.0 - 1.0;
	
	return projMAD(gbufferProjectionInverse, screenPos) / (screenPos.z * gbufferProjectionInverse[2].w + gbufferProjectionInverse[3].w);
}

vec3 ViewSpaceToScreenSpace(vec3 viewSpacePosition) {
	return projMAD(gbufferProjection, viewSpacePosition) / -viewSpacePosition.z * 0.5 + 0.5;
}


#include "/lib/Fragment/Water_Waves.fsh"
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

#include "lib/Misc/EquirectangularProjection.glsl"
#include "/lib/Misc/Bias_Functions.glsl"
#include "/lib/Fragment/Sunlight/ComputeUniformlySoftShadows.fsh"
#include "/lib/Fragment/Reflectance_Models.fsh"

#include "/lib/Fragment/Reflection_Functions.fsh"

vec2 GetRefractedCoord(vec2 coord, vec3 viewSpacePosition, vec3 tangentNormal) {
	vec4 screenSpacePosition = gbufferProjection * vec4(viewSpacePosition, 1.0);
	
	float fov = atan(1.0 / gbufferProjection[1].y) * 2.0 / RAD;
	
	cfloat refractAmount = 0.5;
	
	vec2 refraction = tangentNormal.st / fov * 90.0 * refractAmount;
	
	vec2 refractedCoord = screenSpacePosition.st + refraction;
	
	refractedCoord = refractedCoord / screenSpacePosition.w * 0.5 + 0.5;
	
	refractedCoord = clampScreen(refractedCoord, pixelSize);
	
	return refractedCoord;
}

mat3 DecodeTBN(float tbnIndex) {
	tbnIndex = round(tbnIndex * 16.0);
	
	vec3 tangent;
	vec3 binormal;
	
	if (tbnIndex == 1.0) {
		tangent  = vec3( 0.0,  0.0,  1.0);
		binormal = vec3( 0.0, -1.0,  0.0);
	} else if (tbnIndex == 2.0) {
		tangent  = vec3( 0.0,  0.0,  1.0);
		binormal = vec3( 0.0,  1.0,  0.0);
	} else if (tbnIndex == 3.0) {
		tangent  = vec3( 1.0,  0.0,  0.0);
		binormal = vec3( 0.0,  1.0,  0.0);
	} else if (tbnIndex == 4.0) {
		tangent  = vec3( 1.0,  0.0,  0.0);
		binormal = vec3( 0.0, -1.0,  0.0);
	} else if (tbnIndex == 5.0) {
		tangent  = vec3(-1.0,  0.0,  0.0);
		binormal = vec3( 0.0,  0.0, -1.0);
	} else {
		tangent  = vec3( 1.0,  0.0,  0.0);
		binormal = vec3( 0.0,  0.0, -1.0);
	}
	
	vec3 normal = cross(tangent, binormal);

	return mat3(tangent, binormal, normal);
}

#include "lib/Fragment/WaterDepthFog.fsh"

vec3 GetWaterParallaxCoord(vec3 position, mat3 tbnMatrix) {
	vec3 direction = tbnMatrix * normalize(mat3(gbufferModelViewInverse) * position);
	
	position = mat3(gbufferModelViewInverse) * position + cameraPosition;
	
	cvec3 stepSize = vec3(0.6);
	vec3 interval  = direction * stepSize / -direction.z;
	
	float currentHeight = GetWaves(position);
	vec3  offset = vec3(0.0, 0.0, 1.0);
	
	for (int i = 0; currentHeight < offset.z && i < 120; i++) {
		offset += interval * pow(offset.z - currentHeight, 0.8);
		
		currentHeight = GetWaves(position + vec3(offset.x, 0.0, offset.y));
	}
	
	show(interval);
	
	position = position + vec3(offset.x, 0.0, offset.y) - cameraPosition;
	
	return mat3(gbufferModelView) * position;
}

void main() {
	float depth0 = GetDepth(texcoord);

	mat2x3 frontPos; // Position matrices: [0] = View Space, [1] = World Space
	frontPos[0] = CalculateViewSpacePosition(vec3(texcoord, depth0));
	frontPos[1] = transMAD(gbufferModelViewInverse, frontPos[0]);
	
	vec2 encode = Decode16(texture2D(colortex5, texcoord).r);
	float torchLightmap = encode.r;
	Mask mask = CalculateMasks(encode.g);
	
	vec2   refractedCoord = texcoord;
	float  depth1         = depth0;
	mat2x3 backPos        = frontPos;
	vec2   encodedNormal  = vec2(0.0);
	vec3   normal         = vec3(0.0);
	float  alpha          = 0.0;
	
	if (depth0 < 1.0) { // NOT sky
		encodedNormal = texture2D(colortex4, texcoord).xy;
		
		if (mask.transparent > 0.5) { // Layered fragment, back layer is unique and needs to be computed
			mat3 tbnMatrix = DecodeTBN(encodedNormal.x);
			vec3 tangentNormal;
			
			if (mask.water > 0.5) {
			#ifdef WATER_PARALLAX
				frontPos[0] = GetWaterParallaxCoord(frontPos[0], tbnMatrix);
			#endif
				
				tangentNormal.xy = GetWaveNormals(frontPos[0], tbnMatrix[2]);
			} else tangentNormal.xy = Decode16(encodedNormal.y) * 2.0 - 1.0;
			
			tangentNormal.z = sqrt(1.0 - lengthSquared(tangentNormal.xy));
			
			normal = mat3(gbufferModelView) * tbnMatrix * tangentNormal;
			
			
			refractedCoord = GetRefractedCoord(texcoord, frontPos[0], tangentNormal);
			
			depth1 = (mask.hand > 0.5 ? depth0 : GetTransparentDepth(refractedCoord));
			
			backPos[0] = CalculateViewSpacePosition(vec3(refractedCoord, depth1));
			backPos[1] = transMAD(gbufferModelViewInverse, backPos[0]);
			
			alpha = texture2D(colortex2, refractedCoord).r;
		}
	}
	
	vec3 sky = CalculateSky(backPos[0], backPos[1], vec3(0.0), 1.0 - alpha, false, 0.0);

	if (isEyeInWater == 1) sky = WaterFog(sky, frontPos[0], vec3(0.0));
	
	if (depth0 >= 1.0) { gl_FragData[0] = vec4(EncodeColor(sky), 1.0); exit(); return; }
	
	
	float smoothness;
	float skyLightmap;
	Decode16(texture2D(colortex4, texcoord).b, smoothness, skyLightmap);
	smoothness = mix(smoothness, 0.90, mask.water);
	
	vec3 color0 = vec3(0.0);
	vec3 color1 = vec3(0.0);
	
	if (mask.transparent > 0.5) {
		color0 = texture2D(colortex3, refractedCoord).rgb / alpha;
		
		if (any(isnan(color0))) color0 = vec3(0.0);
	} else {
		normal = DecodeNormal(encodedNormal.xy);
	}
	
	color1 = texture2D(colortex1, refractedCoord).rgb;
	
	color0 = mix(color1, color0, mask.transparent - mask.water);
	
	
	ComputeReflectedLight(color0, frontPos, normal, smoothness, skyLightmap, mask);
	
	
	if (depth1 >= 1.0)
		color0 = mix(sky.rgb, color0, mix(alpha, 0.0, isEyeInWater == 1));
	
	
	color0 = mix(color0, sky.rgb, CalculateFogFactor(frontPos[0], FOG_POWER));
	color1 = mix(color1, sky.rgb, CalculateFogFactor(frontPos[0], FOG_POWER));
	
	if (depth1 < 1.0 && mask.transparent > 0.5) color0 = mix(color1, color0, alpha);
	
	
	gl_FragData[0] = vec4(EncodeColor(color0), 1.0);
	
	exit();
}
