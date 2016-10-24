float GetNoise(vec2 position) {
	vec2 whole = floor(position);
	vec2 coord = whole + cubesmooth(position - whole) + 0.5;
	
	return texture2D(noisetex, coord * noiseResInverse).x;
}

vec2 GetNoise2D(vec2 position) {
	vec2 whole = floor(position);
	vec2 coord = whole + cubesmooth(position - whole) + 0.5;
	
	return texture2D(noisetex, coord * noiseResInverse).xy;
}

float GetCoverage(float clouds, float coverage) {
	return cubesmooth(clamp01((coverage + clouds - 1.0) * 1.1 - 0.1));
}

float CloudFBM(vec2 coord, out mat4x2 c, vec3 weights, float weight) {
	float time = CLOUD_SPEED_2D * TIME * 0.01;
	
	c[0]    = coord * 0.007;
	c[0]   += GetNoise2D(c[0]) * 0.3 - 0.15;
	c[0].x  = c[0].x * 0.25 + time;
	
	float cloud = -GetNoise(c[0]);
	
	c[1]    = c[0] * 2.0 - cloud * vec2(0.5, 1.35);
	c[1].x += time;
	
	cloud += GetNoise(c[1]) * weights.x;
	
	c[2]  = c[1] * vec2(9.0, 1.65) + time * vec2(3.0, 0.55) - cloud * vec2(1.5, 0.75);
	
	cloud += GetNoise(c[2]) * weights.y;
	
	c[3]   = c[2] * 3.0 + time;
	
	cloud += GetNoise(c[3]) * weights.z;
	
	cloud  = weight - cloud;
	
	cloud += GetNoise(c[3] * 3.0 + time) * 0.022;
	cloud += GetNoise(c[3] * 9.0 + time * 3.0) * 0.014;
	
	return cloud * 0.63;
}

void Compute2DCloudPlane(inout vec3 color, vec3 worldSpaceVector, vec3 rayPosition, float sunglow, float visibility) {
#ifndef CLOUDS_2D
	return;
#endif
	
	cfloat cloudHeight = 512.0;
	
	vec3 camPos = cameraPosition + rayPosition;
	
	visibility = pow(visibility, 10.0) * pow(abs(worldSpaceVector.y), 0.6);
	
	if (worldSpaceVector.y <= 0.0 != camPos.y >= cloudHeight) return;
	
	
	cfloat coverage = CLOUD_COVERAGE_2D * 1.16;
	cvec3  weights  = vec3(0.5, 0.135, 0.075);
	cfloat weight   = weights.x + weights.y + weights.z;
	
	vec2 coord = worldSpaceVector.xz / worldSpaceVector.y * (cloudHeight - camPos.y) + camPos.xz;
	
	vec4 cloud;
	mat4x2 coords;
	
	cloud.a = CloudFBM(coord, coords, weights, weight);
	cloud.a = GetCoverage(cloud.a, coverage);
	
	vec2 lightOffset = worldLightVector.xz * 0.2;
	
	float sunlight;
	sunlight  = -GetNoise(coords[0] + lightOffset)            ;
	sunlight +=  GetNoise(coords[1] + lightOffset) * weights.x;
	sunlight +=  GetNoise(coords[2] + lightOffset) * weights.y;
	sunlight +=  GetNoise(coords[3] + lightOffset) * weights.z;
	sunlight  = GetCoverage(weight - sunlight, coverage);
	sunlight  = pow(1.3 - sunlight, 7.0);
	sunlight *= mix(pow(cloud.a, 1.6) * 2.5, 1.0, sunglow);
	sunlight *= mix(11.5, 1.0, sqrt(sunglow));
	
	vec3 directColor  = sunlightColor * 2.0;
	     directColor *= 1.0 + pow(sunglow, 10.0) * 10.0 / (sunlight * 0.8 + 0.2);
	     directColor *= mix(vec3(1.0), vec3(0.4, 0.5, 0.6), timeNight);
	
	vec3 ambientColor = mix(skylightColor, directColor, 0.15) * 0.04;
	
	cloud.rgb = mix(ambientColor, directColor, sunlight) * 70.0;
	
	color = mix(color, cloud.rgb, cloud.a * visibility);
}
