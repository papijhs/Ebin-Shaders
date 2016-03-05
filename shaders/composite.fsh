#version 150 compatibility

#define GAMMA 2.2

const int	shadowMapResolution 		= 2160;
const float	shadowDistance 				= 140.0;
const float	shadowIntervalSize 			= 4.0;
const bool	shadowHardwareFiltering0	= true;
const float	sunPathRotation 			= 30.0;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D gdepthtex;
uniform sampler2D shadowcolor;
uniform sampler2DShadow shadow;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

in vec3		lightVector;

in vec2		texcoord;

in vec3		colorSkylight;

vec3 GetDiffuse(in vec2 coord) {
	return texture2D(colortex0, coord).rgb;
}

vec3 GetDiffuseLinear(in vec2 coord) {
	return pow(texture2D(colortex0, coord).rgb, vec3(GAMMA));
}

float GetSkyLightmap(in vec2 coord) {
	return texture2D(colortex1, coord).r;
}

vec3 GetNormal(in vec2 coord) {
	return (gbufferModelView * vec4(texture2D(colortex2, coord).xyz * 2.0 - 1.0, 0.0)).xyz;
}

float GetDepth(in vec2 coord) {
	return texture2D(gdepthtex, coord).x;
}

vec4 GetViewSpacePosition(in vec2 coord, in float depth) {
	vec4
	position = gbufferProjectionInverse * vec4(vec3(coord, depth) * 2.0 - 1.0, 1.0);
	position /= position.w;
	
	return position;
}

vec4 ViewSpaceToWorldSpace(in vec4 viewSpacePosition) {
	return gbufferModelViewInverse * viewSpacePosition;
}

vec4 WorldSpaceToShadowSpace(in vec4 worldSpacePosition) {
	return shadowProjection * shadowModelView * worldSpacePosition;
}

float GetSunlight(in vec4 position) {
	position = ViewSpaceToWorldSpace(position);
	position = WorldSpaceToShadowSpace(position);
	position = position * 0.5 + 0.5;
	
	if (position.x < 0.0 || position.x > 1.0
	||	position.y < 0.0 || position.y > 1.0
	||	position.z < 0.0 || position.z > 1.0
		) return 1.0;
	
	return shadow2D(shadow, position.xyz - vec3(0.0, 0.0, 0.0005)).x;
}

void Tonemap(inout vec3 color) {
	float averageLuminance = 0.65;
	
	vec3 IAverage = vec3(averageLuminance);
	
	vec3 value = color.rgb / (color.rgb + IAverage);
	
	color.rgb = value;
	color.rgb = min(color.rgb, vec3(1.0));
	color.rgb = pow(color.rgb, vec3(1.0 / 2.2));
}

struct Shading {		//Contains all the light levels, or light intensities, without any color
	float sunlight;
	float skylight;
} shading;

struct Lightmap {		//Contains all the light with color/pigment applied
	vec3 sunlight;
	vec3 skylight;
} lightmap;

void main() {
	vec3	diffuse		= GetDiffuseLinear(texcoord);
	float	skyLightmap	= GetSkyLightmap(texcoord);
	
	vec3	normal				= GetNormal(texcoord);
	float	depth				= GetDepth(texcoord);
	vec4	ViewSpacePosition	= GetViewSpacePosition(texcoord, depth);
	float	NdotL				= max(0.0, dot(normal, lightVector));
	
	
	shading.sunlight = NdotL;
	shading.sunlight *= GetSunlight(ViewSpacePosition);
	
	shading.skylight = skyLightmap;
	
	
	lightmap.sunlight = shading.sunlight * vec3(1.0);
	lightmap.skylight = shading.skylight * colorSkylight;
	
	
	vec3
	composite =	lightmap.sunlight / 0.5
			+	lightmap.skylight * 0.5
			;
	
	composite *= diffuse;
	composite = pow(composite, vec3(1.0 / GAMMA));
	
	gl_FragData[0] = vec4(composite, 1.0);
}