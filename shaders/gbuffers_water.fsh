#version 410 compatibility
#define gbuffers_water
#define fsh
#define ShaderStage -1
#include "/lib/Syntax.glsl"


uniform sampler2DShadow shadow;
uniform sampler2D noisetex;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowProjection;

uniform vec3 cameraPosition;

uniform float nightVision;

uniform ivec2 eyeBrightnessSmooth;

uniform int isEyeInWater;
uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;

uniform sampler2D texture;
uniform sampler2D normals;
uniform sampler2D specular;


uniform ivec2 atlasSize;

uniform float frameTimeCounter;
uniform float wetness;
uniform float far;

varying vec3 color;
varying vec2 texcoord;
varying vec2 vertLightmap;

varying mat3 tbnMatrix;

varying mat2x3 position;

varying vec3 worldDisplacement;

flat varying float mcID;
flat varying float materialIDs;


#include "/lib/Settings.glsl"
#include "/lib/Debug.glsl"
#include "/lib/Utility.glsl"
#include "/lib/Uniform/Projection_Matrices.fsh"
#include "/lib/Misc/Calculate_Fogfactor.glsl"
#include "/lib/Fragment/Masks.fsh"

#include "/lib/Uniform/Shading_Variables.glsl"
#include "/lib/Uniform/Shadow_View_Matrix.fsh"
#include "/lib/Fragment/Calculate_Shaded_Fragment.fsh"
#include "/lib/Fragment/Water_Waves.fsh"

vec4 GetDiffuse(vec2 coord) {
	return vec4(color.rgb, 1.0) * texture2D(texture, coord);
}

vec3 GetNormal(vec2 coord) {
#ifdef NORMAL_MAPS
	vec3 normal = texture2D(normals, coord).xyz * 2.0 - 1.0;
#else
	vec3 normal = vec3(0.0, 0.0, 1.0);
#endif
	
	normal.xyz = normalize(tbnMatrix * normal.xyz);
	
	return normal;
}

float GetSpecularity(vec2 coord) {
#ifdef SPECULARITY_MAPS
	float specularity = texture2D(specular, coord).r;
	
	#if defined WEATHER && defined NORMAL_MAPS
		specularity = clamp01(specularity + wetness);
	#endif
	
	return specularity
#else
	return 0.0;
#endif
}

#define WATER_PARALLAX OFF // [ON OFF]

#define WATER_PARALLAX_QUALITY     1.0  // [0.5 1.0 2.0]
#define WATER_PARALLAX_DISTANCE   12.0  // [30.0 60.0 120.0 240.0]
#define WATER_PARALLAX_INTENSITY   1.00 // [0.25 0.50 0.75 1.00 1.50 2.00]

vec2 GetParallaxWave(vec2 worldPos, float angleCoeff) {
	if (!WATER_PARALLAX) return worldPos;
	
	cfloat parallaxDist = WATER_PARALLAX_DISTANCE;
	cfloat distFade     = parallaxDist / 3.0;
	cfloat MinQuality   = 0.5;
	cfloat maxQuality   = 1.5;
	
	float intensity = clamp01((parallaxDist - length(position[1]) * FOV / 90.0) / distFade) * 0.85 * WATER_PARALLAX_INTENSITY;
	
//	if (intensity < 0.01) return worldPos;
	
	float quality = clamp(radians(180.0 - FOV) / max1(pow(length(position[1]), 0.25)), MinQuality, maxQuality) * WATER_PARALLAX_QUALITY;
	
	vec3  tangentRay = normalize(position[1]) * tbnMatrix;
	vec3  stepSize = 0.1 * vec3(1.0, 1.0, 1.0);
	float stepCoeff = -tangentRay.z * 5.0 / stepSize.z;
	
	angleCoeff = clamp01(angleCoeff * 2.0) * stepCoeff;
	
	vec3 step   = tangentRay   * stepSize;
	     step.z = tangentRay.z * -tangentRay.z * 5.0;
	
	float rayHeight = angleCoeff;
	float sampleHeight = GetWaves(worldPos) * angleCoeff;
	
	float count = 0.0;
	
	while(sampleHeight < rayHeight && count++ < 150.0) {
		worldPos  += step.xy * clamp01(rayHeight - sampleHeight);
		rayHeight += step.z;
		
		sampleHeight = GetWaves(worldPos) * angleCoeff;
	}
	
	return worldPos;
}

vec2 GetWaveDifferentials(vec2 coord, cfloat scale) { // Get finite wave differentials for the world-space X and Z coordinates
	mat4x2 c;
	
	float a  = GetWaves(coord, c);
	float aX = GetWaves(coord + vec2(scale,   0.0));
	float aY = GetWaves(c, scale);
	
	return a - vec2(aX, aY);
}

vec3 ViewSpaceToScreenSpace(vec3 viewSpacePosition) {
	return projMAD(projMatrix, viewSpacePosition) / -viewSpacePosition.z * 0.5 + 0.5;
}

vec3 GetWaveNormals(vec3 worldSpacePosition, vec3 flatWorldNormal) {
	if (WAVE_MULT == 0.0) return vec3(0.0, 0.0, 1.0);
	
	SetupWaveFBM();
	
	float angleCoeff  = dotNorm(-position[1].xyz, flatWorldNormal);
	      angleCoeff /= clamp(length(position[1]) * 0.05, 1.0, 10.0);
	      angleCoeff  = clamp01(angleCoeff * 2.5);
	      angleCoeff  = sqrt(angleCoeff);
	
	vec3 worldPos    = position[1] + cameraPos - worldDisplacement;
	     worldPos.xz = worldPos.xz + worldPos.y;
	
	worldPos.xz = GetParallaxWave(worldPos.xz, angleCoeff);
	
//	vec3 p = pos + worldDisplacement - cameraPos;
//	p = p * mat3(gbufferModelViewInverse);
//	p.z = min(-0.0, p.z);
//	p = ViewSpaceToScreenSpace(p);
//	gl_FragDepth = p.z;
	
	vec2 diff = GetWaveDifferentials(worldPos.xz, 0.1) * angleCoeff;
	
	return vec3(diff, sqrt(1.0 - length2(diff)));
}

void main() {
	if (CalculateFogFactor(position[0]) >= 1.0) discard;
	if (!gl_FrontFacing && abs(materialIDs - 4.0) < 0.1) discard;
	
	vec4  diffuse     = GetDiffuse(texcoord);
	vec3  normal      = GetNormal(texcoord);
	float specularity = GetSpecularity(texcoord);
	
	Mask mask = EmptyMask;
	
	if (abs(materialIDs - 4.0) < 0.1) {
		diffuse = vec4(0.215, 0.356, 0.533, 0.75);
		
		normal = tbnMatrix * GetWaveNormals(position[1], tbnMatrix[2]);
		
		specularity = 1.0;
		mask.water = 1.0;
	}
	
	vec3 composite = CalculateShadedFragment(powf(diffuse.rgb, 2.2), mask, vertLightmap.r, vertLightmap.g, vec4(0.0, 0.0, 0.0, 1.0), normal * mat3(gbufferModelViewInverse), specularity, position);
	
	gl_FragData[0] = vec4(Encode4x8F(vec4(specularity, vertLightmap.g, 0.0, 0.1)), EncodeNormalU(normal, mask.water), 0.0, 1.0);
	gl_FragData[1] = vec4(0.0);
	gl_FragData[2] = vec4(1.0, 0.0, 0.0, diffuse.a);
	gl_FragData[3] = vec4(composite, diffuse.a);
	gl_FragData[4] = vec4(0.0);
	
	exit();
}
