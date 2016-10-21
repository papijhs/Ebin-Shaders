#version 410 compatibility
#define composite1
#define fsh
#define ShaderStage 1
#include "/lib/Syntax.glsl"

/* DRAWBUFFERS:14 */

const bool colortex5MipmapEnabled = true;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler2D colortex5;
uniform sampler2D gdepthtex;
uniform sampler2D depthtex1;
uniform sampler2D noisetex;
uniform sampler2D shadowtex1;
uniform sampler2DShadow shadow;

uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowProjection;

uniform vec3 cameraPosition;
uniform vec3 upPosition;

uniform float near;
uniform float far;

uniform float viewWidth;
uniform float viewHeight;

uniform ivec2 eyeBrightnessSmooth;

uniform int isEyeInWater;
uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;

varying vec2 texcoord;

#include "/lib/Settings.glsl"
#include "/lib/Utility.glsl"
#include "/lib/Debug.glsl"
#include "/lib/Uniform/Projection_Matrices.fsh"
#include "/lib/Uniform/Shading_Variables.glsl"
#include "/lib/Uniform/Shadow_View_Matrix.fsh"
#include "/lib/Fragment/Masks.fsh"

vec3 GetDiffuse(vec2 coord) {
	return texture2D(colortex1, coord).rgb;
}

float GetDepth(vec2 coord) {
	return texture2D(gdepthtex, coord).x;
}

float GetTransparentDepth(vec2 coord) {
	return texture2D(depthtex1, coord).x;
}

float ExpToLinearDepth(float depth) {
	return 2.0 * near * (far + near - depth * (far - near));
}

vec3 CalculateViewSpacePosition(vec3 screenPos) {
	screenPos = screenPos * 2.0 - 1.0;
	
	return projMAD(projInverseMatrix, screenPos) / (screenPos.z * projInverseMatrix[2].w + projInverseMatrix[3].w);
}


#include "/lib/Fragment/Calculate_Shaded_Fragment.fsh"

void BilateralUpsample(vec3 normal, float depth, out vec3 GI) {
	GI = vec3(0.0);
	
#if defined GI_ENABLED
	depth = ExpToLinearDepth(depth);
	
	float totalGIWeight = 0.0;
	
	cfloat kernal = 2.0;
	cfloat range = kernal * 0.5 - 0.5;
	
	for(float i = -range; i <= range; i++) {
		for(float j = -range; j <= range; j++) {
			vec2 offset = vec2(i, j) / vec2(viewWidth, viewHeight);
			
			float sampleDepth  = ExpToLinearDepth(texture2D(gdepthtex, texcoord + offset * 8.0).x );
			vec3  sampleNormal =     DecodeNormal(texture2D(colortex4, texcoord + offset * 8.0).xy);
		
			float weight  = 1.0 - abs(depth - sampleDepth);
			      weight *= dot(normal, sampleNormal);
			      weight  = pow(weight, 32);
			      weight  = max(1.0e-6, weight);
			
			GI += pow(texture2DLod(colortex5, texcoord * COMPOSITE0_SCALE + offset * 2.0, 1).rgb, vec3(2.2)) * weight;
			
			totalGIWeight += weight;
		}
	}
	
	GI *= 5.0 / totalGIWeight;
#endif
}

#include "lib/Fragment/Water_Depth_Fog.fsh"

void main() {
	float depth0 = GetDepth(texcoord);
	
	if (depth0 >= 1.0) { discard; }
	
	
	vec2 texure4 = ScreenTex(colortex4).rg;
	
	vec3 normal = DecodeNormal(Decode2x16(texure4.r));
	
	vec4 decode = Decode4x8F(texure4.g);
	
	float smoothness    = decode.g;
	float skyLightmap   = decode.r;
	float torchLightmap = decode.b;
	Mask  mask          = CalculateMasks(decode.a);
	
	float depth1 = mask.hand > 0.5 ? depth0 : GetTransparentDepth(texcoord);
	
	if (depth0 != depth1) {
		vec3 texure0 = texture2D(colortex0, texcoord).rgb;
		
		vec2 ebin;
		Decode16(texure0.b, ebin.r, ebin.g);
		
		mask.transparent = 1.0;
		mask.water   = float(ebin.g >= 1.0);
		mask.matIDs  = 1.0;
		mask.bits.x *= 1.0 - mask.transparent;
		mask.bits.y  = mask.transparent;
		mask.bits.z  = mask.water;
		mask.materialIDs = EncodeMaterialIDs(mask.matIDs, mask.bits);
		
		texure4 = vec2(Encode2x16F(texure0.rg), Encode4x8F(vec4(ebin.r, ebin.g, torchLightmap, mask.materialIDs)));
	}
	
	gl_FragData[1] = vec4(texure4.rg, 0.0, 1.0);
	
	if (depth1 >= 1.0) return;
	
	
	vec3 GI;
	BilateralUpsample(normal, depth1, GI);
	show(GI)
	
	vec3 diffuse = GetDiffuse(texcoord);
	vec3 viewSpacePosition0 = CalculateViewSpacePosition(vec3(texcoord, depth0));
	
	mat2x3 backPos;
	backPos[0] = CalculateViewSpacePosition(vec3(texcoord, depth1));
	backPos[1] = mat3(gbufferModelViewInverse) * backPos[0];
	
	
	vec3 composite  = CalculateShadedFragment(mask, torchLightmap, skyLightmap, GI, normal, smoothness, backPos);
	     composite *= pow(diffuse * 1.2, vec3(2.8));
	
	if (mask.water > 0.5 || isEyeInWater == 1) composite = WaterFog(composite, viewSpacePosition0, backPos[0]);
	
	gl_FragData[0] = vec4(max0(composite), 1.0);
	
	exit();
}
