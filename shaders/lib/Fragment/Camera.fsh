float computeEV100(float aperature, float shutterTime, float ISO) {
    return log2(pow2(aperature) / shutterTime * 100 / ISO);
}

float computeEV100Auto(float avgLuminance) {
    return log2(avgLuminance * 100 / 12.5);
}

float convertEV100ToExposure(float EV100) {
    float maxLuminance = 1.2 * exp2(EV100);
    return 1.0 / maxLuminance;
}

float computeEV(float avgLuminance) {
    cfloat aperature = 1.4;
    cfloat shutterTime = 1.0 / 4.0;
    cfloat ISO = 800.0;

    float EV100 = computeEV100(aperature, shutterTime, ISO);
    float EV100Auto = computeEV100Auto(avgLuminance);
    float EV = convertEV100ToExposure(EV100Auto);

    return EV;
}