#version 120

#define SHADOW_MAP_BIAS 0.8
#define Extended_Shadow_Distance

const float sunPathRotation = -30.0;
const float radians         = 0.0174533;

uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;

varying vec3 color;
varying vec2 texcoord;

varying vec3 vertNormal;

vec4 BiasShadowProjection(in vec4 position) {
	float dist = length(position.xy);
	
	#ifdef Extended_Shadow_Distance
		vec2 pos = abs(position.xy * 1.165);
		dist = pow(pow(pos.x, 8) + pow(pos.y, 8), 1.0 / 8.0);
	#endif
	
	float distortFactor = dist * SHADOW_MAP_BIAS + (1.0 - SHADOW_MAP_BIAS);
	
	vec3 wlv = normalize((shadowModelViewInverse * vec4(0.0, 0.0, 1.0, 0.0)).xyz);
	
	position.xy /= distortFactor;
	
	position.z += 0.01 * pow(1.0 - dot(vertNormal, vec3(0.0, 0.0, 1.0)), 5.0);
	position.z += 0.0025 * (dist + 0.1);
	position.z /= 4.0;
	
	return position;
}

void main() {
	color      = gl_Color.rgb;
	texcoord   = gl_MultiTexCoord0.st;
	vertNormal = gl_NormalMatrix * gl_Normal;
	
	gl_Position = BiasShadowProjection(ftransform());
}