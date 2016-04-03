#version 120

/* DRAWBUFFERS:4 */

const bool shadowtex1Mipmap    = true;
const bool shadowtex1Nearest   = true;
const bool shadowcolor0Mipmap  = true;
const bool shadowcolor0Nearest = false;
const bool shadowcolor1Mipmap  = true;
const bool shadowcolor1Nearest = false;

uniform sampler2D colortex0;
uniform sampler2D colortex3;
uniform sampler2D gdepthtex;
uniform sampler2D noisetex;
uniform sampler2D shadowcolor;
uniform sampler2D shadowcolor1;
uniform sampler2D shadowtex1;
uniform sampler2DShadow shadow;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;
uniform mat4 shadowModelViewInverse;

uniform float viewWidth;
uniform float viewHeight;
uniform float near;
uniform float far;

varying vec2 texcoord;

#include "/lib/Settings.glsl"
#include "/lib/GlobalCompositeVariables.fsh"
#include "/lib/Masks.glsl"
#include "/lib/CalculateFogFactor.glsl"
#include "/lib/ShadingFunctions.fsh"


vec3 EncodeColor(in vec3 color) {    // Prepares the color to be sent through a limited dynamic range pipeline
	return pow(color * 0.001, vec3(1.0 / 2.2));
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

float ExpToLinearDepth(in float depth) {
	return 2.0 * near * (far + near - depth * (far - near));
}

vec4 CalculateViewSpacePosition(in vec2 coord, in float depth) {
	vec4 position  = gbufferProjectionInverse * vec4(vec3(coord, depth) * 2.0 - 1.0, 1.0);
	     position /= position.w;
	
	return position;
}

vec2 BiasShadowMap(in vec2 shadowProjection, out float biasCoeff) {
	biasCoeff = GetShadowBias(shadowProjection);
	return shadowProjection / biasCoeff;
}

vec2 GetDitherred2DNoise(in vec2 coord) {    // Returns a random noise pattern ranging {-1.0 to 1.0} that repeats every 4 pixels
	coord *= vec2(viewWidth, viewHeight);
	coord  = mod(coord, vec2(2 / COMPOSITE0_SCALE));
	coord /= noiseTextureResolution;
	return texture2D(noisetex, coord).xy * 2.0 - 1.0;
}

vec3 ComputeGlobalIllumination(in vec4 position, in vec3 normal, const in float radius, const in float quality, in Mask mask, in vec2 noise) {
	float normalShading = GetNormalShading(normal, mask);
	
	float lightMult = 1.0;
	
	#ifdef GI_BOOST
	float sunlight = ComputeDirectSunlight(position, normalShading);
	lightMult = 1.0 - pow(sunlight, 1) * normalShading * 4.0;
	#endif
	
	position = WorldSpaceToShadowSpace(ViewSpaceToWorldSpace(position)) * 0.5 + 0.5;    // Convert the view-space position to shadow-map coordinates (unbiased)
	normal   = (shadowModelView * gbufferModelViewInverse * vec4(normal, 0.0)).xyz;     // Convert the normal from view-space to shadow-view-space
	
	float biasCoeff = GetShadowBias(position.xy);
	
	vec3 GI = vec3(0.0);
	
	const float brightness  = 30.0 * radius * radius;
	const float interval    = 1.0 / quality;
	const float scale       = 4.0 * radius / 2048.0;
	const float sampleCount = pow(1.0 / interval * 2.0 + 1.0, 2.0);
	
	if (lightMult * brightness < 1.0 && GI_Boost) return vec3(0.0);
	
	for(float x = -1.0; x <= 1.0; x += interval) {
		for(float y = -1.0; y <= 1.0; y += interval) {
			vec2 offset  = vec2(x, y) + noise * interval;
			     offset *= scale * biasCoeff;
			
			vec4 samplePos = vec4(position.xy + offset, 0.0, 1.0);
			
			float sampleBias;
			vec2 mapPos = BiasShadowMap(samplePos.xy * 2.0 - 1.0, sampleBias) * 0.5 + 0.5;
			
			float sampleLod = 3.0 * (1.0 - sampleBias) + 3.0;
			
			samplePos.z = texture2DLod(shadowtex1, mapPos, sampleLod * 0.5).x;
			samplePos.z = ((samplePos.z * 2.0 - 1.0) * 4.0) * 0.5 + 0.5;    // Undo z-shrinking
			
			vec4 position  = shadowProjectionInverse * ( position * 2.0 - 1.0);    // Re-declaring "position" here overrides "position" with a new vec4, but only in the context of the current iterration. Without the declaration, our changes would roll-over to the next iteration because "position"'s scope is the entire function.
			     samplePos = shadowProjectionInverse * (samplePos * 2.0 - 1.0);
			
			vec3 sampleDiff = position.xyz - samplePos.xyz;
			
			float distanceCoeff  = max(length(sampleDiff), radius);
			      distanceCoeff *= distanceCoeff;
			      distanceCoeff  = clamp(1.0 / distanceCoeff, 0.0, 1.0);
			
			vec3 sampleDir    = normalize(sampleDiff);
			vec3 shadowNormal = texture2DLod(shadowcolor1, mapPos, sampleLod).xyz * 2.0 - 1.0;
			
			float viewNormalCoeff   = max(0.0, dot(normalize(      normal), normalize(-sampleDir)));
			float shadowNormalCoeff = max(0.0, dot(normalize(shadowNormal), normalize( sampleDir)));
			
		//	viewNormalCoeff   = viewNormalCoeff * (1.0 - mask.leaves) + mask.leaves * 2.0;
			viewNormalCoeff   = viewNormalCoeff * (1.0 - GI_TRANSLUCENCE) + GI_TRANSLUCENCE;
			
			float sampleCoeff = viewNormalCoeff * sqrt(shadowNormalCoeff) * distanceCoeff;
			
		//	if (sampleCoeff < 0.01 * sampleCount / brightness) continue;    // This should in theory reduce costly texture lookups for redundant pixels, but it seems to just hurt performance most of the time
			
			vec3 flux = 1.0 - texture2DLod(shadowcolor, mapPos, sampleLod).rgb;
			
			GI += flux * sampleCoeff;
		}
	}
	
	GI /= sampleCount;
	
	return GI * lightMult * brightness;    // brightness is constant for all pixels for all samples. lightMult is not constant over all pixels, but is constant over each pixels' samples.
}

float ComputeVolumetricFog(in vec4 viewSpacePosition, in float noise1D) {
	float fog = 0.0;
	
	
	#ifdef FOG_ENABLED
	float weight = 0.0;
	
	float rayIncrement = gl_Fog.start / 64.0;
	vec3  rayStep      = normalize(viewSpacePosition.xyz + vec3(0.0, 0.0, noise1D));
	vec3  ray          = rayStep * gl_Fog.start;
	
	while (length(ray) < length(viewSpacePosition.xyz)) {
		ray += rayStep * rayIncrement;
		
		vec3 samplePosition = BiasShadowProjection(WorldSpaceToShadowSpace(ViewSpaceToWorldSpace(vec4(ray, 1.0)))).xyz * 0.5 + 0.5;
		
		fog += shadow2D(shadow, samplePosition).x * rayIncrement;
		
		weight += rayIncrement;
		
		rayIncrement *= 1.01;
	}
	
	fog /= weight;
	#endif
	
	
	return fog;
}


void main() {
	Mask mask;
	CalculateMasks(mask, texture2D(colortex3, texcoord).b, true);
	
	if (mask.sky > 0.5)
		{ gl_FragData[0] = vec4(0.0, 0.0, 0.0, 1.0); return; }
	
	float depth             = texture2D(gdepthtex, texcoord).x;
	vec4  viewSpacePosition = CalculateViewSpacePosition(texcoord, depth);
	vec2  noise2D           = GetDitherred2DNoise(texcoord);
	
	float Fog = ComputeVolumetricFog(viewSpacePosition, noise2D.x);
	
	if (mask.water > 0.5)
		{ gl_FragData[0] = vec4(0.0, 0.0, 0.0, Fog); return; }
	
	vec3 normal = GetNormal(texcoord);
	
	vec3 GI = ComputeGlobalIllumination(viewSpacePosition, normal, 16.0, 4.0, mask, noise2D);
	
	gl_FragData[0] = vec4(EncodeColor(GI), Fog);
}