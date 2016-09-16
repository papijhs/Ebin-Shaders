#ifdef CUSTOM_TIME_CYCLE	

varying mat4 shadowView;

#define shadowViewMatrix shadowView

float timeCycle;
float timeAngle;
float pathRotationAngle;
float twistAngle;


#include "/lib/EbinScript/Load.vsh"
#include "/UserProgram/CustomTimeCycle.vsh"
#include "/lib/EbinScript/Unload.vsh"

void GetDaylightVariables(out float isNight, out vec3 worldLightVector) {
	
	timeAngle = sunAngle * 360.0;
	pathRotationAngle = sunPathRotation;
	twistAngle = 0.0;
	
	
	UserRotation();
	
	
	timeCycle = timeAngle;
	
	isNight = float(mod(timeAngle, 360.0) > 180.0 != mod(abs(pathRotationAngle) + 90.0, 360.0) > 180.0); // When they're not both above or below the horizon
	
	//sunTimeAngle = -mod(timeAngle, 360.0) * RAD;
	timeAngle = -mod(timeAngle, 180.0) * RAD;
	
	pathRotationAngle = (mod(pathRotationAngle + 90.0, 180.0) - 90.0) * RAD;
	twistAngle *= RAD;
	
	
	float A = cos(pathRotationAngle);
	float B = sin(pathRotationAngle);
	float C = cos(timeAngle);
	float D = sin(timeAngle);
	float E = cos(twistAngle);
	float F = sin(twistAngle);
	
	shadowView = mat4(
	-D*E + B*C*F,  -A*F,  C*E + B*D*F,  shadowModelView[0].w,
	        -A*C,    -B,         -A*D,  shadowModelView[1].w,
	 B*C*E + D*F,  -A*E,  B*D*E - C*F,  shadowModelView[2].w,
	 shadowModelView[3]);
	
	worldLightVector = vec3(F*B*D + E*C,  -A*D,  E*B*D - F*C);
}
#else

void GetDaylightVariables(out float isNight, out vec3 worldLightVector) {
	isNight = float(sunAngle > 0.5);
	
	worldLightVector = shadowModelViewInverse[2].xyz;
}

#define shadowViewMatrix shadowModelView

#endif

void CalculateShadowView() {
	float isNight;
	vec3  worldLightVector;
	
	GetDaylightVariables(isNight, worldLightVector);
}
