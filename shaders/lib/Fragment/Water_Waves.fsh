float GetWave(vec2 coord) {
	vec2 whole = floor(coord);
	
	coord = floor(coord) + cubesmooth(coord - whole) + 0.5;
	
	return texture2D(noisetex, coord * noiseResInverse).x;
}

float SharpenWave(float wave) {
	wave = 1.0 - abs(wave * 2.0 - 1.0);
	
	return wave < 0.78 ? wave : (wave * -2.5 + 5.0) * wave - 1.6;
}

cvec4 heights = vec4(29.0, 15.0, 17.0, 4.0);
cvec4 height = heights * WAVE_MULT / sum4(heights);

cvec2 scale1 = vec2(0.0065, 0.0052  ) * noiseRes;
cvec2 scale2 = vec2(0.013 , 0.00975 ) * noiseRes;
cvec2 scale3 = vec2(0.0195, 0.014625) * noiseRes;
cvec2 scale4 = vec2(0.0585, 0.04095 ) * noiseRes;

cvec2 disp1 = vec2(0.0135 , -0.0165) * noiseRes;
cvec2 disp2 = vec2(0.017  , -0.018 ) * noiseRes;
cvec2 disp3 = vec2(0.0555 , -0.027 ) * noiseRes;
cvec2 disp4 = vec2(0.00825, -0.0405) * noiseRes;

vec2 waveTime1;
vec2 waveTime2;
vec2 waveTime3;
vec2 waveTime4;

void SetupWaveFBM() {
	float waveTime = TIME * WAVE_SPEED * 0.6;
	
	waveTime1 = waveTime * disp1;
	waveTime2 = waveTime * disp2;
	waveTime3 = waveTime * disp3;
	waveTime4 = waveTime * disp4;
}

float GetWaves(vec2 coord) {
	vec2 c = coord;
	
	float waves = 0.0;
	
	c = coord * scale1 + waveTime1;
	c.y += c.x * -1.7;
	
	waves += SharpenWave(GetWave(c)) * height.x;
	
	c = coord * scale2 + waveTime2;
	c.y += c.x * -1.7;
	
	waves += GetWave(c) * height.y;
	
	c = coord * scale3 + waveTime3;
	c.y += c.x * 1.1;
	
	waves += GetWave(c) * height.z;
	
	c = coord * scale4 + waveTime4;
	c.y += c.x * -1.05;
	
	waves += GetWave(c) * height.w;
	
	return waves;
}

vec2 GetWaveDifferentials(vec2 coord, cfloat scale) { // Get finite wave differentials for the world-space X and Z coordinates
	float a  = GetWaves(coord                     );
	float aX = GetWaves(coord + vec2(scale,   0.0));
	float aY = GetWaves(coord + vec2(  0.0, scale));
	
	return a - vec2(aX, aY);
}

#if defined gbuffers_water
vec2 GetParallaxWave(vec2 worldPos, float angleCoeff) {
#ifndef WATER_PARALLAX
	return worldPos;
#endif
	
	vec3  tangentRay = normalize(position[1]) * tbnMatrix;
	vec3  stepSize = 0.1 * vec3(1.0, 1.0, 1.0);
	float stepCoeff = -tangentRay.z * 5.0 / stepSize.z;
	
	vec3  step = tangentRay * stepSize;
	
	angleCoeff = clamp01(angleCoeff * 2.0);
	
	float rayHeight = angleCoeff;
	float sampleHeight = GetWaves(worldPos) * angleCoeff;
	
	float count = 0.0;
	
	while(sampleHeight < rayHeight && count++ < 150.0) {
		worldPos  += step.xy * clamp01((rayHeight - sampleHeight) * stepCoeff);
		rayHeight += step.z;
		
		sampleHeight = GetWaves(worldPos) * angleCoeff;
	}
	
	return worldPos;
}

vec3 ViewSpaceToScreenSpace(vec3 viewSpacePosition) {
	return projMAD(projMatrix, viewSpacePosition) / -viewSpacePosition.z * 0.5 + 0.5;
}

vec3 GetWaveNormals(vec3 worldSpacePosition, vec3 flatWorldNormal) {
	SetupWaveFBM();
	
	float angleCoeff  = -dot(flatWorldNormal, normalize(position[1].xyz));
	      angleCoeff /= clamp(length(position[1]) * 0.05, 1.0, 10.0);
	      angleCoeff  = clamp01(angleCoeff * 2.5);
	      angleCoeff  = sqrt(angleCoeff);
	
	vec3 worldPos    = position[1] + cameraPos - worldDisplacement;
	     worldPos.xz = worldPos.xz + worldPos.y;
	
	worldPos.xz = GetParallaxWave(worldPos.xz, angleCoeff);
	
//	vec3 p = pos + worldDisplacement - cameraPos;
//	p = p * mat3(gbufferModelViewInverse);
//	p.z = min(-0.0, p.z);
//	p = ViewSpaceToScreenSpace(p);
//	gl_FragDepth = p.z;
	
	vec2 diff = GetWaveDifferentials(worldPos.xz, 0.1) * angleCoeff;
	
	return vec3(diff, sqrt(1.0 - length2(diff)));
}
#endif
