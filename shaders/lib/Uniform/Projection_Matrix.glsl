#ifndef FOV_OVERRIDE

#define projectionMatrix gbufferProjection

#else

varying mat4 projMatrix;

#define projectionMatrix projMatrix

#if defined vsh
#include "/lib/Uniform/Setup_Projection_Matrix.vsh"
#endif


#endif
