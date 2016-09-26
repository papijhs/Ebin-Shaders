vec3 CalculateEquirectangularPosition(vec2 coord) {
    coord.y -= 0.5;
    cvec2 sphericalTranslation = vec2(2.0 * PI, PI);

    vec2 sphericalCoord = coord * sphericalTranslation;
    float longitude = sphericalCoord.x;
    float latitude = sphericalCoord.y - (2.0 * PI);

    float cosLat = cos(latitude);

    vec3 sphericalPosition = vec3(cosLat * cos(longitude), cosLat * sin(longitude), sin(latitude));

    return normalize(sphericalPosition);
}

vec3 ProjectEquirectangularPositions(sampler2D equiRectangular, vec3 direction, float lod) {
    float longitude = atan(direction.z, direction.x);
    if(direction.z < 0.0) longitude = 2.0 * PI - atan(-direction.z, direction.x);

    float latitude = acos(direction.y);

    cvec2 radians = vec2(1.0 / (2.0 * PI), 1.0 / PI);
    vec2 sphereCoords = vec2(longitude, latitude) * radians;
    sphereCoords.y = 1.0 - sphereCoords.y;

    return texture2DLod(equiRectangular, sphereCoords, lod).rgb;
}