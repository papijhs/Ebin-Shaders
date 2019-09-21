#version 410 compatibility
#define gbuffers_water
#define vsh
#define ShaderStage -2
#include "/../shaders/lib/Syntax.glsl"


uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;

uniform float sunAngle;


#include "/../shaders/gbuffers_main.vsh"
