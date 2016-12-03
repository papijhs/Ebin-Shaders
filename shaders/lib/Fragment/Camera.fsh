float computeEV100(float aperature, float shutterTime, float ISO) {
    return log2(pow2(aperature) / shutterTime * 100 / ISO);
}

float convertEV100ToExposure(float EV100) {
    float maxLuminance = 1.2 * exp2(EV100);
    return 1.0 / maxLuminance;
}

vec3 convertLuminance2Color(vec3 luminance) {
    cfloat aperature = 8.4;
    cfloat shutterTime = 1.0 / 125.0;
    cfloat ISO = 100.0;

    float EV100 = computeEV100(aperature, shutterTime, ISO);
    float EV = convertEV100ToExposure(EV100);

    return luminance * EV;
}