#version 410 compatibility
#define gbuffers_water
#define fsh
#define ShaderStage -1
#include "/lib/Syntax.glsl"


uniform sampler2DShadow shadow;

uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowProjection;

uniform vec3 cameraPosition;

uniform ivec2 eyeBrightnessSmooth;
uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;


#include "gbuffers_main.fsh"
