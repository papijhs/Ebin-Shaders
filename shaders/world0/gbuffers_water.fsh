#version 410 compatibility
#define gbuffers_water
#define fsh
#define world0
#define ShaderStage -1
#include "/../shaders/lib/Syntax.glsl"


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


#include "/../shaders/gbuffers_main.fsh"
