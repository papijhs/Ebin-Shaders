#define length2_(type) float length2(type x) { return dot(x, x); }
DEFINE_genFType(length2_)

#define length8_(type) float length8(type x) { \
	x *= x; \
	x *= x; \
	return pow(dot(x, x), 0.125); \
}
DEFINE_genFType(length8_)

float lengthN(vec2 x, float N) {
	x = pow(abs(x), vec2(N));
	return pow(x.x + x.y, 1.0 / N);
}
