uniform vec3 sunPosition;
uniform vec3 upPosition;

varying vec3 lightVector;

varying float timeDay;
varying float timeNight;
varying float timeHorizon;

varying vec3 colorSunlight;
varying vec3 colorSkylight;
varying vec3 colorHorizon;

float clamp01(in float x) {
	return clamp(x, 0.0, 1.0);
}