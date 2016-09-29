vec3 CalculateEquirectangularPosition(vec2 coord) {
    float alpha = 2.0 * PI * (0.5 - coord.x);
    float theta = PI * coord.y;
    float sine = sin(theta);

    return vec3(cos(alpha) * sine, sin(alpha) * sine, cos(theta));
}

vec3 rEnv(vec3 direction) {
    return vec3(direction.x, direction.z, direction.y);
}

vec3 ProjectEquirectangularPositions(sampler2D equiRectangular, vec3 direction, float lod) {
    vec2 sphericalCoords = vec2(0.5 - atan(direction.y, direction.x) / (PI * 2.0), acos(direction.z) / PI);

    return texture2DLod(equiRectangular, (sphericalCoords), lod).rgb;
}