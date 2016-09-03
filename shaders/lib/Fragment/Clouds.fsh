float Get3DNoise(vec3 position) {
	vec3 part  = floor(position);
	vec3 whole = position - part;
	
	cvec2 zscale = vec2(17.0, 0.0);
	
	vec4 coord  = part.xyxy + whole.xyxy + part.z * zscale.x + zscale.yyxx + 0.5;
	     coord /= noiseTextureResolution;
	
	float Noise1 = texture2D(noisetex, coord.xy).x;
	float Noise2 = texture2D(noisetex, coord.zw).x;
	
	return mix(Noise1, Noise2, whole.z);
}

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
