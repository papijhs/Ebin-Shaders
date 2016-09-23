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
