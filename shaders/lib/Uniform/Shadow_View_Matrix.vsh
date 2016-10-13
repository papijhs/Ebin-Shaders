#ifdef CUSTOM_TIME_CYCLE	
	varying mat4 shadowView;
	
	#define shadowViewMatrix shadowView
	
	vec3 sunAngles; // (time, path rotation, twist)
	
	#define timeAngle sunAngles.x
	#define pathRotationAngle sunAngles.y
	#define twistAngle sunAngles.z
	
	
	#include "/lib/EbinScript/Load.vsh"
	#include "/UserProgram/CustomTimeCycle.vsh"
	#include "/lib/EbinScript/Unload.vsh"
	
	void GetDaylightVariables(out float isNight, out vec3 worldLightVector) {
		timeAngle = sunAngle * 360.0;
		pathRotationAngle = sunPathRotation;
		twistAngle = 0.0;
		
		
		TimeOverride();
		
		
		isNight = float(mod(timeAngle, 360.0) > 180.0 != mod(abs(pathRotationAngle) + 90.0, 360.0) > 180.0); // When they're not both above or below the horizon
		
		timeAngle = -mod(timeAngle, 180.0);
		pathRotationAngle = (mod(pathRotationAngle + 90.0, 180.0) - 90.0);
		
		sunAngles = radians(sunAngles);
		
		vec3 cosine = cos(sunAngles);
		vec3   sine = sin(sunAngles);
		
		#define A cosine.x
		#define B   sine.x
		#define C cosine.y
		#define D   sine.y
		#define E cosine.z
		#define F   sine.z
		
		shadowView = mat4(
		-B*E + D*A*F,  -C*F,  A*E + D*B*F,  shadowModelView[0].w,
				-C*A,    -D,         -C*B,  shadowModelView[1].w,
		 D*A*E + B*F,  -C*E,  D*B*E - A*F,  shadowModelView[2].w,
		 shadowModelView[3]);
		
		worldLightVector = vec3(F*D*B + E*A,  -C*B,  E*D*B - F*A);
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
