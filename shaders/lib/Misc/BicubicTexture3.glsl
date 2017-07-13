vec4 cubic(float x) {
	float x2 = x * x;
	float x3 = x2 * x;
	vec4 w;
	
	w.x =   -x3 + 3*x2 - 3*x + 1;
	w.y =  3*x3 - 6*x2       + 4;
	w.z = -3*x3 + 3*x2 + 3*x + 1;
	w.w =  x3;
	
	return w / 6.0;
}

vec3 BicubicTexture(sampler2D tex, vec2 coord) { // 3-Component (.rgb) bicubic texture lookup
	coord *= vec2(viewWidth, viewHeight);
	
	vec2 f = fract(coord);
	
	coord -= f;
	
	vec4 xcubic = cubic(f.x);
	vec4 ycubic = cubic(f.y);
	
	vec4 c = coord.xxyy + vec2(-0.5, 1.5).xyxy;
	vec4 s = vec4(xcubic.xz + xcubic.yw, ycubic.xz + ycubic.yw);
	
	vec4 offset  = c + vec4(xcubic.yw, ycubic.yw) / s;
	     offset *= pixelSize.xxyy;
	
	vec3 sample0 = texture2D(tex, offset.xz).rgb;
	vec3 sample1 = texture2D(tex, offset.yz).rgb;
	vec3 sample2 = texture2D(tex, offset.xw).rgb;
	vec3 sample3 = texture2D(tex, offset.yw).rgb;
	
	float sx = s.x / (s.x + s.y);
	float sy = s.z / (s.z + s.w);
	
	return mix(mix(sample3, sample2, sx), mix(sample1, sample0, sx), sy);
}