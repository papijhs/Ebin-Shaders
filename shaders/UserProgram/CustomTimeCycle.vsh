
// Start of #include "/UserProgram/CustomTimeCycle.vsh"


/* Availible variables:
 * 
 * float time:     Counts up 1.0 every frame
 * vec3  position: The player's world space position
 * float dayCycle: Cycles from 0.0 to 1.0 over the course of a day
 * 
 * 
 * Output variables:
 * 
 * timeAngle:         The angle that by default determines what time of day it is
 * pathRotationAngle: The angle that by default is determined by the "Sun Path Rotation" setting
 * twistAngle:        Rotates the sun around the y-axis
 * 
 * All outputs are floating point degree units.
*/


void UserRotation() {
	#if TIME_OVERRIDE_MODE == 1
		
		timeAngle = CONSTANT_TIME_HOUR * 15.0;
		
	#elif TIME_OVERRIDE_MODE == 2
		
		timeAngle = mod(timeAngle, 180.0) + 180.0 * float(CUSTOM_DAY_NIGHT == 2);
		
	#elif TIME_OVERRIDE_MODE == 3
		
		
		#if CUSTOM_TIME_MISC == 1
			twistAngle = 90.0;
		#elif CUSTOM_TIME_MISC == 2
			
			// Debug Stuff goes here
			timeAngle = position.x * 25;
			
		#endif
		
		
	#endif
}

// End of #include "/UserProgram/CustomTimeCycle.vsh"
