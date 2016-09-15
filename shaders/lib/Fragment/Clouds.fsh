#include "/lib/Misc/Get3DNoise.glsl"

vec3 Compute2DCloudPlane(vec3 worldSpacePosition, vec3 worldSpaceVector, vec4 viewRayPosition, float sunglow) {
#ifndef ENABLE_CLOUDS
	return vec3(0.0);
#endif
	
	cfloat cloudHeight = 512.0;
	
	vec3 camPos = cameraPosition + mat3(gbufferModelViewInverse) * viewRayPosition.xyz;
	
	if (worldSpaceVector.y <= 0.0 != camPos.y >= cloudHeight) return vec3(0.0);
	
	
	vec3 coord = worldSpaceVector / worldSpaceVector.y * (cloudHeight - camPos.y) + camPos;
	
	vec3 color = vec3(pow(cosmooth(cosmooth(GetWaves(coord * 0.01))), 6.0)) * 20.0 * abs(worldSpaceVector.y);
	
	return vec3(color);
}
