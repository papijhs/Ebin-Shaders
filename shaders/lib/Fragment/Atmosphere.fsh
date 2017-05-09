#define iSteps 12

cfloat expCoeff = 1.0;

cfloat     planetRadius = 6371.0e2;
cfloat atmosphereRadius = 6471.0e2;

cfloat atmosphereHeight = atmosphereRadius - planetRadius;

cvec2 radiiSquared = pow(vec2(planetRadius, atmosphereRadius), vec2(2.0));

cvec3  rayleighCoeff = vec3(5.8e-6, 1.35e-5, 3.31e-5) * -expCoeff;
cfloat      mieCoeff = 7e-6 * -expCoeff;

cfloat rayleighHeight = 8.0e3 * 0.25;
cfloat      mieHeight = 1.2e3 * 2.0;

cvec2 invScatterHeight = (-1.0 / vec2(rayleighHeight, mieHeight) * expCoeff); // Optical step constant to save computations inside the loop

vec2 AtmosphereDistances(vec3 worldPosition, vec3 worldDirection) {
	// Considers the planet's center as the coordinate origin, as per convention
	
	float b  = -dot(worldPosition, worldDirection);
	float bb = b * b;
	vec2  c  = dot(worldPosition, worldPosition) - radiiSquared;
	
	vec2 delta   = sqrt(max(bb - c, 0.0)); // .x is for planet distance, .y is for atmosphere distance
	     delta.x = -delta.x; // Invert delta.x so we don't have to subtract it later
	
	if (worldPosition.y < atmosphereRadius) { // Uniform condition
		if (bb < c.x || b < 0.0) return vec2(b + delta.y, 0.0); // If the earth is not visible to the ray, check against the atmosphere instead
		
		vec2 dist     = b + delta;
		vec3 hitPoint = worldPosition + worldDirection * dist.x;
		
		float horizonCoeff = dotNorm(hitPoint, worldDirection);
		      horizonCoeff = exp2(horizonCoeff * 5.0 * expCoeff);
		
		return vec2(mix(dist.x, dist.y, horizonCoeff), 0.0);
	} else {
		if (b < 0.0) return vec2(0.0);
		
		if (bb < c.x) return vec2(2.0 * delta.y, b - delta.y);
		
		return vec2((delta.y + delta.x) * 2.0, b - delta.y);
	}
}

vec3 ComputeAtmosphericSky(vec3 playerSpacePosition, vec3 worldPosition, vec3 pSun, float visibility, cfloat iSun) {
	vec3 worldDirection = normalize(playerSpacePosition);
	
	vec2 atmosphereDistances = AtmosphereDistances(worldPosition, worldDirection);
	
	if (atmosphereDistances.x <= 0.0) return vec3(0.0);
	
	float iStepSize = atmosphereDistances.x / float(iSteps); // Calculate the step size of the primary ray
	vec4 iStepSize2 = vec2(log2(iStepSize), 0.0).xxyy - planetRadius * invScatterHeight.rgrg;
	vec3  iStep     = worldDirection * iStepSize;
	
	vec3 rayleigh = vec3(0.0); // Initialize accumulators for Rayleigh and Mie scattering
	vec3 mie      = vec3(0.0);
	
	vec2 opticalDepth = vec2(0.0); // Initialize optical depth accumulators, .rg represents rayleigh and mie for the 'i' loop, .ba represent the same for the 'j' loop
	
	vec3 iPos = worldPosition + worldDirection * (iStepSize * 0.5 + atmosphereDistances.y); // Calculate the primary ray sample position
	
	
	vec3 c = vec3(dot(iPos, iPos), dot(iPos, iStep) * 2.0, dot(iStep, iStep));
	float pSunLen2 = dot(pSun, pSun) * 0.25;
	
	vec2 e = vec2(dot(iPos, pSun), dot(iStep, pSun));
	
    // Sample the primary ray
	for (float i = 0; i < iSteps; i++) {
		float iPosLength2 = fma(fma(c.z, i, c.y), i, c.x);
		
		float b = fma(e.y, i, e.x); // b = dot(iPos, pSun);
		float jStepSize = sqrt(fma(b, b, radiiSquared.y - iPosLength2)) - b; // jStepSize = sqrt(b*b + radiiSquared.y - dot(iPos, iPos)) - b;
		
		float jPosLength2 = fma(fma(pSunLen2, jStepSize, b), jStepSize, iPosLength2);
		
		vec4 opticalStep = exp2(sqrt(vec2(iPosLength2, jPosLength2)).xxyy * invScatterHeight.rgrg + iStepSize2); // Calculate the optical depth of the Rayleigh and Mie scattering for this step
		opticalDepth += opticalStep.rg; // Accumulate optical depth
		opticalStep.ba = opticalStep.ba * jStepSize + opticalDepth;
		
		vec3 attn = exp2(rayleighCoeff * opticalStep.b + (mieCoeff * opticalStep.a));
		
		rayleigh += opticalStep.r * attn;
		mie      += opticalStep.g * attn;
    }
	
	// Calculate the Rayleigh and Mie phases
	float g = 0.9 * sqrt(visibility);
	float gg = g * g;
    float  mu = dot(worldDirection, pSun);
    float rayleighPhase = 1.5 * (1.0 + mu * mu);
    float      miePhase = rayleighPhase * (1.0 - gg) / (pow(1.0 + gg - 2.0 * mu * g, 1.5) * (2.0 + gg));
	
	mie = max0(mie);
	
    // Calculate and return the final color
    return iSun * (rayleigh * rayleighPhase * rayleighCoeff + mie * miePhase * mieCoeff) / -expCoeff;
}
