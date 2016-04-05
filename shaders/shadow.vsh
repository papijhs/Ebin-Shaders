#version 120

#define SHADOW_MAP_BIAS 0.8
#define EXTENDED_SHADOW_DISTANCE
#define FORWARD_SHADING

attribute vec4 mc_Entity;

uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;

varying vec3 color;
varying vec2 texcoord;

varying vec3 vertNormal;


vec4 BiasShadowProjection(in vec4 position) {
	float biasCoeff = length(position.xy);
	
	#ifdef EXTENDED_SHADOW_DISTANCE
		vec2 pos = abs(position.xy * 1.165);
		biasCoeff = pow(pow(pos.x, 8) + pow(pos.y, 8), 1.0 / 8.0);
	#endif
	
	biasCoeff = biasCoeff * SHADOW_MAP_BIAS + (1.0 - SHADOW_MAP_BIAS);
	
	position.z  += 0.001 * (1.0 - sqrt(dot(vertNormal, vec3(0.0, 0.0, 1.0))));    // Offset the z-coordinate to fix shadow acne
	position.z  += 0.0005 / (abs(position.x) + 1.0);
	position.z  += 0.002 * pow(biasCoeff * 2.0, 2.0);
	
	position.xy /= biasCoeff;
	
	position.z  /= 4.0;    // Shrink the domain of the z-buffer. This counteracts the noticable issue where far terrain would not have shadows cast, especially when the sun was near the horizon
	
	return position;
}

void main() {
	color      = gl_Color.rgb;
	texcoord   = gl_MultiTexCoord0.st;
	vertNormal = gl_NormalMatrix * gl_Normal;
	
	gl_Position = BiasShadowProjection(ftransform());
	
	#ifdef FORWARD_SHADING
		if (abs(mc_Entity.x - 8.5) < 0.6) gl_Position.w = -1.0;
	#else
		if (abs(mc_Entity.x - 8.5) < 0.6) color.rgb *= 0.0;
	#endif
}