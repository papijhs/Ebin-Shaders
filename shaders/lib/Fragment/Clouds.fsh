#include "/lib/Misc/Get3DNoise.glsl"

vec3 Compute2DCloudPlane(vec3 worldSpacePosition, vec3 worldSpaceVector) {
#ifndef ENABLE_CLOUDS
	return vec3(0.0);
#endif
	
	cfloat cloudHeight = 512.0;
	
	if (worldSpaceVector.y <= 0.0 != cameraPosition.y >= cloudHeight) return vec3(0.0);
	
	
	vec3 coord = worldSpaceVector / worldSpaceVector.y * (cloudHeight - cameraPosition.y) + cameraPosition;
	
	vec3 color = vec3(pow(cosmooth(cosmooth(GetWaves(coord * 0.01))), 6.0)) * 20.0 * abs(worldSpaceVector.y);
	
	return vec3(color);
}
