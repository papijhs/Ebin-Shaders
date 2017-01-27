float GetWave(vec2 coord) {
	coord *= noiseRes;
	coord  = floor(coord) + cubesmooth(fract(coord)) + 0.5;
	
	return texture2D(noisetex, coord * noiseResInverse).x;
}

float SharpenWave(float wave) {
	wave = 1.0 - abs(wave * 2.0 - 1.0);
	
	if (wave > 0.78) wave = 5.0 * wave - pow2(wave) * 2.5 - 1.6;
	
	return wave;
}

float GetWaves(vec3 position) {
	float time = TIME * WAVE_SPEED * 0.6;
	
	vec2 pos  = position.xz + position.y;
	     pos += time * vec2(1.0, -1.0);
	     pos *= 0.065;
	
	
	float weight, waves, weights;
	
	
	pos = pos / 2.1 - vec2(time / 30.0, time * 0.03);
	
	weight   = 4.0;
	waves   += GetWave(vec2(pos.x * 2.0, pos.y * 1.4 + pos.x * -2.1)) * weight;
	weights += weight;
	
	
	pos = pos / 1.5 + vec2(time / 20.0, 0.0);
	
	weight   = 17.0;
	waves   += GetWave(vec2(pos.x, pos.y * 0.75 + pos.x * 1.1)) * weight;
	weights += weight;
	
	
	pos = pos / 1.5 - vec2(time / 55.0, 0.0);
	
	weight   = 15.0;
	waves   += GetWave(vec2(pos.x, pos.y * 0.75 + pos.x * -1.7)) * weight;
	weights += weight;
	
	
	pos = pos / 1.9 + vec2(time * 0.8 / 155.0, 0.0);
	
	weight   = 29.0;
	waves   += SharpenWave(GetWave(vec2(pos.x, pos.y * 0.8 + pos.x * -1.7))) * weight;
	weights += weight;
	
	
	return waves / weights;
}

vec2 GetWaveDifferentials(vec3 position, cfloat scale) { // Get finite wave differentials for the world-space X and Z coordinates
	float a  = GetWaves(position                          );
	float aX = GetWaves(position + vec3(scale, 0.0,   0.0));
	float aY = GetWaves(position + vec3(  0.0, 0.0, scale));
	
	return a - vec2(aX, aY);
}


vec3 GetWaveNormals(vec3 worldSpacePosition, vec3 flatWorldNormal) {
	vec2 diff = GetWaveDifferentials(worldSpacePosition + cameraPos, 0.1);
	
	float viewVectorCoeff  = -dot(flatWorldNormal, normalize(worldSpacePosition.xyz));
	      viewVectorCoeff /= clamp(length(worldSpacePosition) * 0.05, 1.0, 10.0);
	      viewVectorCoeff  = clamp01(viewVectorCoeff * 2.5);
	      viewVectorCoeff  = sqrt(viewVectorCoeff);
	
	diff *= WAVE_MULT * viewVectorCoeff;
	
	return vec3(diff, sqrt(1.0 - length2(diff)));
}
