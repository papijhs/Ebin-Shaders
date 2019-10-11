#include "/../shaders/lib/Syntax.glsl"


varying vec2 texcoord;

#include "/../shaders/lib/Uniform/Shading_Variables.glsl"


/***********************************************************************/
#if defined vsh

uniform sampler3D colortex7;

uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

uniform float sunAngle;
uniform float frameTimeCounter;
uniform float far;

#include "/../shaders/lib/Settings.glsl"
#include "/../shaders/lib/Utility.glsl"
#include "/../shaders/lib/Debug.glsl"
#include "/../shaders/lib/Uniform/Projection_Matrices.vsh"
#include "/../shaders/UserProgram/centerDepthSmooth.glsl"
#include "/../shaders/lib/Uniform/Shadow_View_Matrix.vsh"
#include "/../shaders/lib/Fragment/PrecomputedSky.glsl"
#include "/../shaders/lib/Vertex/Shading_Setup.vsh"

void main() {
	texcoord    = gl_MultiTexCoord0.st;
	gl_Position = ftransform();
	
	SetupProjection();
	SetupShading();
}

#endif
/***********************************************************************/



/***********************************************************************/
#if defined fsh

uniform sampler3D colortex7;

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

uniform vec2 pixelSize;

uniform float frameTimeCounter;
uniform float rainStrength;

uniform float near;
uniform float far;

uniform ivec2 eyeBrightnessSmooth;

uniform int isEyeInWater;

#include "/../shaders/lib/Settings.glsl"
#include "/../shaders/lib/Utility.glsl"
#include "/../shaders/lib/Debug.glsl"
#include "/../shaders/lib/Uniform/Projection_Matrices.fsh"
#include "/../shaders/lib/Uniform/Shadow_View_Matrix.fsh"
#include "/../shaders/lib/Fragment/Masks.fsh"
#include "/../shaders/lib/Misc/CalculateFogfactor.glsl"


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

#include "/../shaders/lib/Fragment/WaterDepthFog.fsh"
#include "/../shaders/lib/Fragment/ComputeSunlight.fsh"
#include "/../shaders/lib/Fragment/Sky.fsh"
#include "/../shaders/lib/Fragment/ComputeSSReflections.fsh"


/* DRAWBUFFERS:32 */
#include "/../shaders/lib/Exit.glsl"

vec3 ComputeReflectiveSurface(float depth0, float depth1, mat2x3 frontPos, mat2x3 backPos, vec3 normal, float smoothness, float skyLightmap, Mask mask, out vec3 alpha, vec3 transmit) {
	vec3 color = vec3(0.0);
	
	alpha = vec3(1.0);
	
	if (mask.transparent == 1.0) {
		color += texture2D(colortex3, texcoord).rgb;
		alpha *= clamp01(1.0 - texture2D(colortex3, texcoord).a);
	}

	if (depth1 < 1.0) {
		if (mask.water == 1.0)
			WaterDepthFog(frontPos[0], backPos[0] * (1-isEyeInWater), alpha);
		
		color += texture2D(colortex1, texcoord).rgb * alpha;
		
		alpha *= 0.0;
	}

	if (mask.water == 1.0 && depth1 >= 1.0)
		alpha *= 0.0;

	if (depth0 < 1.0)
		ComputeSSReflections(color, frontPos, normal, smoothness, skyLightmap);
	
	return color * transmit;
}

void main() {
	vec2 texture4 = ScreenTex(colortex4).rg;
	
	vec4  decode4       = Decode4x8F(texture4.r);
	Mask  mask          = CalculateMasks(decode4.r);
	float smoothness    = decode4.g;
	float skyLightmap   = decode4.a;
	
	gl_FragData[1] = vec4(decode4.r, 0.0, 0.0, 1.0);
	
	float depth0 = (mask.hand > 0.5 ? 0.55 : GetDepth(texcoord));
	
	vec3 normal = DecodeNormal(texture4.g, 11) * mat3(gbufferModelViewInverse);
	
	mat2x3 frontPos;
	frontPos[0] = CalculateViewSpacePosition(vec3(texcoord, depth0));
	frontPos[1] = mat3(gbufferModelViewInverse) * frontPos[0];
	
	float  depth1  = depth0;
	mat2x3 backPos = frontPos;
	float  alpha   = 0.0;
	
	if (mask.transparent > 0.5) {
		depth1     = (mask.hand > 0.5 ? 0.55 : GetTransparentDepth(texcoord));
		alpha      = texture2D(colortex3, texcoord).a;
		backPos[0] = CalculateViewSpacePosition(vec3(texcoord, depth1));
		backPos[1] = mat3(gbufferModelViewInverse) * backPos[0];
	}
	
	if (true || cameraPosition.y >= CLOUD_HEIGHT_2D) { // Above clouds
		vec3 alpha = vec3(1.0);
		vec3 fogTransmit = vec3(1.0);
		vec3 color = vec3(0.0);
		vec3 fog = (depth0 < 1.0) ? SkyAtmosphereToPoint(vec3(0.0), frontPos[1], fogTransmit) : vec3(0.0);
		
		color = fog + ComputeReflectiveSurface(depth0, depth1, frontPos, backPos, normal, smoothness, skyLightmap, mask, alpha, fogTransmit);
		
		if (alpha.r + alpha.g + alpha.b > 0.0) {
			color += ComputeSky(normalize(frontPos[1]), vec3(0.0), alpha, 1.0, false);
		}
		
		gl_FragData[0] = vec4(clamp01(EncodeColor(color)), 1.0);
		exit();
		return;
		
	} else if (isEyeInWater == 0) { // Below clouds and above water (common case)
		
	} else if (isEyeInWater == 1) { // Underwater
		
	}
	
	vec3 transmit = vec3(1.0);
	vec3 sky      = (depth1 >= 1.0) ? ComputeSky(normalize(backPos[1]), backPos[1], transmit, 1.0, false) : vec3(0.0);
	
	transmit = vec3(1.0);
	vec3 in_scatter = WaterDepthFog(frontPos[0], backPos[0] * (1-isEyeInWater), transmit);
	sky *= transmit;
	
	
//	else if (mask.water    > 0.5) sky = mix(WaterDepthFog(sky, frontPos[0], backPos[0]), sky, CalculateFogfactor(frontPos[0], FOG_POWER));
	
	if (depth0 >= 1.0) { gl_FragData[0] = vec4(EncodeColor(sky), 1.0); exit(); return; }
	
	
	vec3 color0 = vec3(0.0);
	vec3 color1 = texture2D(colortex1, texcoord).rgb;
	
	if      (mask.transparent == 1.0)
		color0 = texture2D(colortex3, texcoord).rgb / alpha;
	else if (mask.transparent - mask.water < 0.5)
		color0 = color1;
	
	ComputeSSReflections(color0, frontPos, normal, smoothness, skyLightmap);
	
	
	transmit = vec3(1.0);
	
	vec3 fog = SkyAtmosphereToPoint(vec3(0.0), frontPos[1], transmit);
	color0 = color0 * transmit + fog;
//	color0 *= WaterDepthFog(frontPos[0], backPos[0]);
	gl_FragData[0] = vec4(clamp01(EncodeColor(color0)), 1.0);
	
	exit();
}

#endif
/***********************************************************************/
