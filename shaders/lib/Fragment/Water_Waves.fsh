float GetWave(vec2 coord) {
	coord *= noiseRes;
	coord  = floor(coord) + cubesmooth(fract(coord)) + 0.5;
	
	return texture2D(noisetex, coord * noiseResInverse).x;
}

float SharpenWave(float wave) {
	wave = 1.0 - abs(wave * 2.0 - 1.0);
	
	return wave < 0.78 ? wave : (wave * -2.5 + 5.0) * wave - 1.6;
}

cfloat wave1 = 29.0 * WAVE_MULT / 65.0;
cfloat wave2 = 15.0 * WAVE_MULT / 65.0;
cfloat wave3 = 17.0 * WAVE_MULT / 65.0;
cfloat wave4 =  4.0 * WAVE_MULT / 65.0;

float GetWaves(vec3 position) {
	float time = TIME * WAVE_SPEED * 0.6;
	
	vec2 pos = position.xz + position.y;
	     pos = pos * 0.0065 + time * vec2(0.0065, -0.0065);
	
	float waves = 0.0;
	
	pos = pos + vec2(time * 0.007, time * -0.01);
	
	waves += SharpenWave(GetWave(vec2(pos.x, pos.y * 0.8 + pos.x * -1.7))) * wave1;
	
	pos = pos * 2.0 + vec2(time * -0.01, time * 0.015);
	
	waves += GetWave(vec2(pos.x, pos.y * 0.75 + pos.x * -1.7)) * wave2;
	
	pos = pos * 1.5 + vec2(time * 0.03, 0.0);
	
	waves += GetWave(vec2(pos.x, pos.y * 0.75 + pos.x * 1.1)) * wave3;
	
	pos = pos * 1.5 + vec2(time * -0.075, 0.0);
	
	waves += GetWave(vec2(pos.x * 2.0, pos.y * 1.4 + pos.x * -2.1)) * wave4;
	
	return waves;
}

vec2 GetWaveDifferentials(vec3 position, cfloat scale) { // Get finite wave differentials for the world-space X and Z coordinates
	float a  = GetWaves(position                          );
	float aX = GetWaves(position + vec3(scale, 0.0,   0.0));
	float aY = GetWaves(position + vec3(  0.0, 0.0, scale));
	
	return a - vec2(aX, aY);
}

vec3 GetParallaxWave(vec3 worldPos, float angleCoeff) {
#ifndef WATER_PARALLAX
	return worldPos;
#endif
	
	vec3  tangentRay = normalize(position[1]) * tbnMatrix;
	vec3  stepSize = 0.5 * vec3(1.0, 1.0, 1.0);
	float stepCoeff = -tangentRay.z * 5.0 / stepSize.z;
	
	vec3  step = tangentRay * stepSize;
	
	angleCoeff = clamp01(angleCoeff * 2.0);
	
	float rayHeight = angleCoeff;
	float sampleHeight = GetWaves(worldPos) * angleCoeff;
	
	float count = 0.0;
	
	while(sampleHeight < rayHeight && count++ < 100.0) {
		worldPos.xz += step.xy * clamp01((rayHeight - sampleHeight) * stepCoeff);
		rayHeight   += step.z;
		
		sampleHeight = GetWaves(worldPos) * angleCoeff;
	}
	
	return worldPos;
}

vec3 ViewSpaceToScreenSpace(vec3 viewSpacePosition) {
	return projMAD(projMatrix, viewSpacePosition) / -viewSpacePosition.z * 0.5 + 0.5;
}

vec3 GetWaveNormals(vec3 worldSpacePosition, vec3 flatWorldNormal) {
	float angleCoeff  = -dot(flatWorldNormal, normalize(position[1].xyz));
	      angleCoeff /= clamp(length(position[1]) * 0.05, 1.0, 10.0);
	      angleCoeff  = clamp01(angleCoeff * 2.5);
	      angleCoeff  = sqrt(angleCoeff);
	
	vec3 pos = GetParallaxWave(position[1] + cameraPos - worldDisplacement, angleCoeff);
	
//	vec3 p = pos + worldDisplacement - cameraPos;
//	p = p * mat3(gbufferModelViewInverse);
//	p.z = min(-0.0, p.z);
//	p = ViewSpaceToScreenSpace(p);
//	gl_FragDepth = p.z;
	
	vec2 diff = GetWaveDifferentials(pos, 0.1);
	
	diff *= angleCoeff;
	
	return vec3(diff, sqrt(1.0 - length2(diff)));
}
