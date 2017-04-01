float length2(vec2 x) {
	return dot(x, x);
}

float length2(vec3 x) {
	return dot(x, x);
}

float length8(vec2 x) {
	x *= x;
	x *= x;
	return pow(dot(x, x), 0.125);
}

float lengthN(vec2 x, float N) {
	x = pow(abs(x), vec2(N));
	return pow(x.x + x.y, 1.0 / N);
}
