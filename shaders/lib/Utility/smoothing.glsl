float cubesmooth(float x) { return (x * x) * (3.0 - 2.0 * x); } // Applies a subtle S-shaped curve, domain [0 to 1]
vec2  cubesmooth(vec2  x) { return (x * x) * (3.0 - 2.0 * x); }
vec3  cubesmooth(vec3  x) { return (x * x) * (3.0 - 2.0 * x); }

#define cosmooth(x) (0.5 - cos((x) * PI) * 0.5) // Same concept as cubesmooth, slightly different distribution
