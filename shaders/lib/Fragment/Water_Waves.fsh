float GetWave(vec2 coord) {
	vec2 whole = floor(coord);
	
	coord = floor(coord) + cubesmooth(coord - whole) + 0.5;
	
	return texture2D(noisetex, coord * noiseResInverse).x;
}

float GetWave1(vec2 coord) {
	coord *= noiseRes;
	coord  = floor(coord) + cubesmooth(fract(coord)) + 0.5;
	
	return texture2D(noisetex, coord * noiseResInverse).x;
}

float SharpenWave(float wave) {
	wave = 1.0 - abs(wave * 2.0 - 1.0);
	
	return wave < 0.78 ? wave : (wave * -2.5 + 5.0) * wave - 1.6;
}

cvec4 heights = vec4(29.0, 15.0, 17.0, 4.0);
cvec4 height = heights * WAVE_MULT / sum4(heights);

cvec4 scales = vec4(0.0065, 0.013, 0.0195, 0.02925) * noiseRes;

cvec2 disp1 = vec2(0.0135 , -0.0165) * noiseRes;
cvec2 disp2 = vec2(0.017  , -0.018 ) * noiseRes;
cvec2 disp3 = vec2(0.0555 , -0.027 ) * noiseRes;
cvec2 disp4 = vec2(0.00825, -0.0405) * noiseRes;

float waveTime;
vec2  waveTime1;
vec2  waveTime2;
vec2  waveTime3;
vec2  waveTime4;

float GetWaves1(vec3 position) {
	vec2 pos = position.xz + position.y;
	     pos = pos * 0.0065 + waveTime * vec2(0.0065, -0.0065);
	
	float waves = 0.0;
	
	pos = pos + vec2(waveTime * 0.007, waveTime * -0.01);
	
	waves += SharpenWave(GetWave1(vec2(pos.x, pos.y * 0.8 + pos.x * -1.7))) * height.x;
	
	pos = pos * 2.0 + vec2(waveTime * -0.01, waveTime * 0.015);
	
	waves += GetWave1(vec2(pos.x, pos.y * 0.75 + pos.x * -1.7)) * height.y;
	
	pos = pos * 1.5 + vec2(waveTime * 0.03, 0.0);
	
	waves += GetWave1(vec2(pos.x, pos.y * 0.75 + pos.x * 1.1)) * height.z;
	
	pos = pos * 1.5 + vec2(waveTime * -0.075, 0.0);
	
	waves += GetWave1(vec2(pos.x * 2.0, pos.y * 1.4 + pos.x * -2.1)) * height.w;
	
	return waves;
}

float GetWaves(vec2 pos) {
	vec2 p1 = pos;
	
	float waves = 0.0;
	
	pos = p1 * scales.x + waveTime1;
	pos.y = pos.y * 0.8 + pos.x * -1.7;
	
	waves += SharpenWave(GetWave(pos)) * height.x;
	
	pos = p1 * scales.y + waveTime2;
	pos.y = pos.y * 0.75 + pos.x * -1.7;
	
	waves += GetWave(pos) * height.y;
	
	pos = p1 * scales.z + waveTime3;
	pos.y = pos.y * 0.75 + pos.x * 1.1;
	
	waves += GetWave(pos) * height.z;
	
	pos = p1 * scales.w + waveTime4;
	pos = vec2(pos.x * 2.0, pos.y * 1.4 + pos.x * -2.1);
	
	waves += GetWave(pos) * height.w;
	
	return waves;
}

vec2 GetWaveDifferentials(vec3 position, cfloat scale) { // Get finite wave differentials for the world-space X and Z coordinates
	float a  = GetWaves1(position                          );
	float aX = GetWaves1(position + vec3(scale, 0.0,   0.0));
	float aY = GetWaves1(position + vec3(  0.0, 0.0, scale));
	
	return a - vec2(aX, aY);
}

vec3 GetParallaxWave1(vec3 worldPos, float angleCoeff) {
#ifndef WATER_PARALLAX
	return worldPos;
#endif
	
	vec3  tangentRay = normalize(position[1]) * tbnMatrix;
	vec3  stepSize = 0.5 * vec3(1.0, 1.0, 1.0);
	float stepCoeff = -tangentRay.z * 5.0 / stepSize.z;
	
	vec3  step = tangentRay * stepSize;
	
	angleCoeff = clamp01(angleCoeff * 2.0);
	
	float rayHeight = angleCoeff;
	float sampleHeight = GetWaves1(worldPos) * angleCoeff;
	
	float count = 0.0;
	
	while(sampleHeight < rayHeight && count++ < 150.0) {
		worldPos.xz += step.xy * clamp01((rayHeight - sampleHeight) * stepCoeff);
		rayHeight   += step.z;
		
		sampleHeight = GetWaves1(worldPos) * angleCoeff;
	}
	
	return worldPos;
}

vec3 GetParallaxWave(vec3 worldPos, float angleCoeff) {
#ifndef WATER_PARALLAX
	return worldPos;
#endif
	
	float y = worldPos.y;
	worldPos.xz += y;
	
	vec3  tangentRay = normalize(position[1]) * tbnMatrix;
	vec3  stepSize = 0.1 * vec3(1.0, 1.0, 1.0);
	float stepCoeff = -tangentRay.z * 5.0 / stepSize.z;
	
	vec3  step = tangentRay * stepSize;
	
	angleCoeff = clamp01(angleCoeff * 2.0);
	
	float rayHeight = angleCoeff;
	float sampleHeight = GetWaves(worldPos.xz) * angleCoeff;
	
	float count = 0.0;
	
	while(sampleHeight < rayHeight && count++ < 150.0) {
		worldPos.xz += step.xy * clamp01((rayHeight - sampleHeight) * stepCoeff);
		rayHeight   += step.z;
		
		sampleHeight = GetWaves(worldPos.xz) * angleCoeff;
	}
	
	worldPos.xz -= y;
	
	return worldPos;
}

vec3 ViewSpaceToScreenSpace(vec3 viewSpacePosition) {
	return projMAD(projMatrix, viewSpacePosition) / -viewSpacePosition.z * 0.5 + 0.5;
}

vec3 GetWaveNormals(vec3 worldSpacePosition, vec3 flatWorldNormal) {
	waveTime  = TIME * WAVE_SPEED * 0.6;
	waveTime1 = waveTime * disp1;
	waveTime2 = waveTime * disp2;
	waveTime3 = waveTime * disp3;
	waveTime4 = waveTime * disp4;
	
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
