#version 120

/* DRAWBUFFERS:2 */

#define GAMMA 2.2
#define SHADOW_MAP_BIAS 0.8
#define Extended_Shadow_Distance

const int   shadowMapResolution      = 2160;
const float shadowDistance           = 140.0;
const float shadowIntervalSize       = 4.0;
const float sunPathRotation          = 30.0;
const bool  shadowHardwareFiltering0 = true;

const int RGB8            = 0;
const int RG16            = 0;
const int RGB16           = 0;
const int colortex0Format = RG16;
const int colortex2Format = RGB16;
const int colortex3Format = RGB8;

uniform sampler2D colortex0;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
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

uniform float sunAngle;

varying vec3 lightVector;

varying vec2 texcoord;

varying vec3 colorSkylight;


float GetMaterialIDs(in vec2 coord) {    //Function that retrieves the texture that has all material IDs stored in it
	return texture2D(colortex3, coord).b;
}

void DecodeMaterialIDs(inout float matID, inout float bit0, inout float bit1, inout float bit2, inout float bit3) {
	matID *= 255.0;
	
	if (matID >= 128.0 && matID < 254.5) {
		matID -= 128.0;
		bit0 = 1.0;
	}
	
	if (matID >= 64.0 && matID < 254.5) {
		matID -= 64.0;
		bit1 = 1.0;
	}
	
	if (matID >= 32.0 && matID < 254.5) {
		matID -= 32.0;
		bit2 = 1.0;
	}
	
	if (matID >= 16.0 && matID < 254.5) {
		matID -= 16.0;
		bit3 = 1.0;
	}
}

float GetMaterialMask(in float mask, in float materialID) {
	return float(abs(materialID - mask) < 0.1);
}

vec3 GetDiffuse(in vec2 coord) {
	return texture2D(colortex2, coord).rgb;
}

vec3 GetDiffuseLinear(in vec2 coord) {
	return pow(texture2D(colortex2, coord).rgb, vec3(GAMMA));
}

float GetTorchLightmap(in vec2 coord) {
	float torchlight = 1.0 - pow(texture2D(colortex3, coord).r, 4.0);
	      torchlight = 1.0 / pow(torchlight, 2.0) - 1.0;
	
	return torchlight;
}

float GetSkyLightmap(in vec2 coord) {
	return pow(texture2D(colortex3, coord).g, 4.0);    //Best to do this falloff curve after sending the number through the 8-bit pipeline
}

vec3 DecodeNormal(vec2 encodedNormal) {
	encodedNormal = encodedNormal * 2.0 - 1.0;
    vec2 fenc = encodedNormal * 4.0 - 2.0;
	float f = dot(fenc, fenc);
	float g = sqrt(1.0 - f / 4.0);
	vec3 normal;
	normal.xy = fenc * g;
	normal.z = 1.0 - f / 2.0;
	return normal;
}

vec3 GetNormal(in vec2 coord) {
	return DecodeNormal(texture2D(colortex0, coord).xy);
}

float GetDepth(in vec2 coord) {
	return texture2D(gdepthtex, coord).x;
}

vec4 GetViewSpacePosition(in vec2 coord, in float depth) {
	vec4 position  = gbufferProjectionInverse * vec4(vec3(coord, depth) * 2.0 - 1.0, 1.0);
	     position /= position.w;
	
	return position;
}

vec4 ViewSpaceToWorldSpace(in vec4 viewSpacePosition) {
	return gbufferModelViewInverse * viewSpacePosition;
}

vec4 WorldSpaceToShadowSpace(in vec4 worldSpacePosition) {
	return shadowProjection * shadowModelView * worldSpacePosition;
}

vec4 BiasWorldPosition(in vec4 position) {
	position = shadowModelView * position;
	vec2 pos = abs((shadowProjection * position).xy * 1.165);
	float dist = pow(pow(pos.x, 8) + pow(pos.y, 8), 1.0 / 8.0);
	position.x += 0.5 * dist * SHADOW_MAP_BIAS * mix(1.0, -1.0, float(mod(sunAngle, 0.5) > 0.25));
	position = shadowModelViewInverse * position;
	
	return position;
}

vec4 BiasShadowProjection(in vec4 position) {
	float dist = length(position.xy);
	
	#ifdef Extended_Shadow_Distance
		vec2 pos = abs(position.xy * 1.165);
		dist = pow(pow(pos.x, 8) + pow(pos.y, 8), 1.0 / 8.0);
	#endif
	
	float distortFactor = (1.0 - SHADOW_MAP_BIAS) + dist * SHADOW_MAP_BIAS;
	
	position.xy /= distortFactor;
	
	position.z /= 4.0;
	
	return position;
}

float GetSunlight(in vec4 position) {
	position = ViewSpaceToWorldSpace(position);
	position = BiasWorldPosition(position);
	position = WorldSpaceToShadowSpace(position);
	position = BiasShadowProjection(position); 
	position = position * 0.5 + 0.5;
	
	if (position.x < 0.0 || position.x > 1.0
	||  position.y < 0.0 || position.y > 1.0
	||  position.z < 0.0 || position.z > 1.0
	    ) return 1.0;
	
	float sunlight = shadow2D(shadow, position.xyz).x;
	      sunlight = pow(sunlight, 2.0);    //Fatten the shadow up to soften its penumbra
	
	return sunlight;
}

vec3 Tonemap(in vec3 color) {
	return pow(color / (color + vec3(0.6)), vec3(1.0 / 2.2));
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

struct Mask {
	float materialIDs;
	float matIDs;
	
	float bit0;
	float bit1;
	float bit2;
	float bit3;
	
	float sky;
};

struct Shading {     //Contains all the light levels, or light intensities, without any color
	float normal;    //Coefficient of light intensity based on the dot product of the normal vector and the light vector
	float sunlight;
	float skylight;
	float torchlight;
	float ambient;
};

struct Lightmap {    //Contains all the light with color/pigment applied
	vec3 sunlight;
	vec3 skylight;
	vec3 torchlight;
	vec3 ambient;
};

void CalculateMasks(inout Mask mask) {
	mask.materialIDs = GetMaterialIDs(texcoord);
	mask.matIDs      = mask.materialIDs;
	
	DecodeMaterialIDs(mask.matIDs, mask.bit0, mask.bit1, mask.bit2, mask.bit3);
	
	mask.sky = GetMaterialMask(255, mask.matIDs);
}

void main() {
	Mask mask;
	CalculateMasks(mask);
	
	vec3 diffuse = GetDiffuseLinear(texcoord);
	
	if (mask.sky > 0.5) { diffuse = Tonemap(diffuse); gl_FragData[0] = vec4(diffuse, 1.0); return; }
	
	float torchLightmap     = GetTorchLightmap(texcoord);
	float skyLightmap       = GetSkyLightmap(texcoord);
	vec3  normal            = GetNormal(texcoord);
	float depth             = GetDepth(texcoord);
	vec4  ViewSpacePosition = GetViewSpacePosition(texcoord, depth);
	
	Shading shading;
	shading.normal = max(0.0, dot(normal, lightVector));
	
	shading.sunlight  = shading.normal;
	shading.sunlight *= GetSunlight(ViewSpacePosition);
	
	shading.torchlight = torchLightmap;
	
	shading.skylight = skyLightmap;
	
	shading.ambient = 1.0;
	
	
	Lightmap lightmap;
	lightmap.sunlight = shading.sunlight * vec3(1.0);
	
	lightmap.torchlight = shading.torchlight * vec3(1.0, 0.25, 0.05);
	
	lightmap.skylight = shading.skylight * colorSkylight;
	
	lightmap.ambient = shading.ambient * vec3(1.0);
	
	
	vec3 composite = (
	    lightmap.sunlight   * 4.0
	+   lightmap.torchlight
	+   lightmap.skylight   * 0.4
	+   lightmap.ambient    * 0.003
	    ) * diffuse;
	
	composite = Uncharted2Tonemap(composite);
	
	gl_FragData[0] = vec4(composite, 1.0);
}