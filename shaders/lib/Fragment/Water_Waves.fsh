float GetWaveCoord(float coord) {
	cfloat madd = 0.5 * noiseResInverse;
	float whole = floor(coord);
	coord = whole + cubesmooth(coord - whole);
	
	return coord * noiseResInverse + madd;
}

vec2 GetWaveCoord(vec2 coord) {
	cvec2 madd = vec2(0.5 * noiseResInverse);
	vec2 whole = floor(coord);
	coord = whole + cubesmooth(coord - whole);
	
	return coord * noiseResInverse + madd;
}

float SharpenWave(float wave) {
	wave = 1.0 - abs(wave * 2.0 - 1.0);
	
	return wave < 0.78 ? wave : (wave * -2.5 + 5.0) * wave - 1.6;
}

cvec4 heights = vec4(29.0, 15.0, 17.0, 4.0);
cvec4 height = heights * WAVE_MULT / sum4(heights);

cvec2 scale1 = vec2(0.0065, 0.0052  ) * noiseRes * noiseScale;
cvec2 scale2 = vec2(0.013 , 0.00975 ) * noiseRes * noiseScale;
cvec2 scale3 = vec2(0.0195, 0.014625) * noiseRes * noiseScale;
cvec2 scale4 = vec2(0.0585, 0.04095 ) * noiseRes * noiseScale;

cvec2 stretch1 = vec2(scale1.x * -1.7 , 0.0);
cvec2 stretch2 = vec2(scale2.x * -1.7 , 0.0);
cvec2 stretch3 = vec2(scale3.x *  1.1 , 0.0);
cvec2 stretch4 = vec2(scale4.x * -1.05, 0.0);

cvec2 disp1 = vec2(0.04155, -0.0165   ) * noiseRes * noiseScale;
cvec2 disp2 = vec2(0.017  , -0.0469   ) * noiseRes * noiseScale;
cvec2 disp3 = vec2(0.0555 ,  0.03405  ) * noiseRes * noiseScale;
cvec2 disp4 = vec2(0.00825, -0.0491625) * noiseRes * noiseScale;

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

float GetWaves(vec2 coord, io mat4x3 c) {
	float waves = 0.0;
	
	c[0].xy = coord * scale1 + waveTime1;
	c[0].z  = coord.x * stretch1.x + c[0].y;
	c[0].xy = GetWaveCoord(c[0].xz);
	
	waves += SharpenWave(texture2D(noisetex, c[0].xy).x) * height.x;
	
	c[1].xy = coord * scale2 + waveTime1;
	c[1].z  = coord.x * stretch2.x + c[1].y;
	c[1].xy = GetWaveCoord(c[1].xz);
	
	waves += texture2D(noisetex, c[1].xy).x * height.y;
	
	c[2].xy = coord * scale3 + waveTime1;
	c[2].z  = coord.x * stretch3.x + c[2].y;
	c[2].xy = GetWaveCoord(c[2].xz);
	
	waves += texture2D(noisetex, c[2].xy).x * height.z;
	
	c[3].xy = coord * scale4 + waveTime1;
	c[3].z  = coord.x * stretch4.x + c[3].y;
	c[3].xy = GetWaveCoord(c[3].xz);
	
	waves += texture2D(noisetex, c[3].xy).x * height.w;
	
	return waves;
}

float GetWaves(vec2 coord) {
	mat4x3 c;
	
	return GetWaves(coord, c);
}

float GetWaves(mat4x3 c, vec2 offset) {
	float waves = 0.0;
	
	c[0].y = GetWaveCoord(offset.y * scale1.y + c[0].z);
	
	waves += SharpenWave(texture2D(noisetex, c[0].xy).x) * height.x;
	
	c[1].y = GetWaveCoord(offset.y * scale2.y + c[1].z);
	
	waves += texture2D(noisetex, c[1].xy).x * height.y;
	
	c[2].y = GetWaveCoord(offset.y * scale3.y + c[2].z);
	
	waves += texture2D(noisetex, c[2].xy).x * height.z;
	
	c[3].y = GetWaveCoord(offset.y * scale4.y + c[3].z);
	
	waves += texture2D(noisetex, c[3].xy).x * height.w;
	
	return waves;
}

vec2 GetWaveDifferentials(vec2 coord, cfloat scale) { // Get finite wave differentials for the world-space X and Z coordinates
	mat4x3 c;
	
	float a  = GetWaves(coord, c);
	float aX = GetWaves(coord + vec2(scale,   0.0));
	float aY = GetWaves(c,      vec2(  0.0, scale));
	
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
