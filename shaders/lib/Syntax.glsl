#if defined fsh
	#define varying in
#endif

#if defined vsh
	#define attribute in
	#define varying out
#endif

#define io inout

#define FORCE_COMPATIBILITY

#if defined FORCE_COMPATIBILITY || defined GL_VENDOR_INTEL
	#define COMPATIBILITY
#endif

#ifndef COMPATIBILITY
	#define ENABLE_CONST
#endif

#ifdef ENABLE_CONST
	#define cbool  const bool
	#define cbvec2 const bvec2
	#define cbvec3 const bvec3
	#define cbvec4 const bvec4
	
	#define cuint  const uint
	#define cuvec2 const uvec2
	#define cuvec3 const uvec3
	#define cuvec4 const uvec4
	
	#define cint   const int
	#define civec2 const ivec2
	#define civec3 const ivec3
	#define civec4 const ivec4
	
	#define cfloat const float
	#define cvec2  const vec2
	#define cvec3  const vec3
	#define cvec4  const vec4
#else
	#define cbool  bool
	#define cbvec2 bvec2
	#define cbvec3 bvec3
	#define cbvec4 bvec4
	
	#define cuint  uint
	#define cuvec2 uvec2
	#define cuvec3 uvec3
	#define cuvec4 uvec4
	
	#define cint   int
	#define civec2 ivec2
	#define civec3 ivec3
	#define civec4 ivec4
	
	#define cfloat float
	#define cvec2  vec2
	#define cvec3  vec3
	#define cvec4  vec4
#endif
