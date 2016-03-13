#define SHADOW_MAP_BIAS 0.8    //[0.0 0.6 0.7 0.8 0.85 0.9]
#define SOFT_SHADOWS
#define EXTENDED_SHADOW_DISTANCE

void DecodeMaterialIDs(inout float matID, inout float bit0, inout float bit1, inout float bit2, inout float bit3) {
	matID *= 255.0;
	
	if (matID >= 128.0 && matID < 254.5) {
		matID -= 128.0;
		bit0 = 1.0;
	}
	
	if (matID >= 64.0 && matID < 254.5) {
		matID -= 64.0;
		bit1 = 1.0;
	}
	
	if (matID >= 32.0 && matID < 254.5) {
		matID -= 32.0;
		bit2 = 1.0;
	}
	
	if (matID >= 16.0 && matID < 254.5) {
		matID -= 16.0;
		bit3 = 1.0;
	}
}

float GetMaterialMask(in float mask, in float materialID) {
	return float(abs(materialID - mask) < 0.1);
}

void CalculateMasks(inout Mask mask, in float materialIDs, const bool encoded) {
	mask.materialIDs = materialIDs;
	mask.matIDs      = mask.materialIDs;
	
	if (encoded) DecodeMaterialIDs(mask.matIDs, mask.bit0, mask.bit1, mask.bit2, mask.bit3);
	
	mask.grass  = GetMaterialMask(2, mask.matIDs);
	mask.leaves = GetMaterialMask(3, mask.matIDs);
	mask.sky    = GetMaterialMask(255, mask.matIDs);
}

vec4 ViewSpaceToWorldSpace(in vec4 viewSpacePosition) {
	return gbufferModelViewInverse * viewSpacePosition;
}

vec4 WorldSpaceToShadowSpace(in vec4 worldSpacePosition) {
	return shadowProjection * shadowModelView * worldSpacePosition;
}

vec4 BiasShadowProjection(in vec4 position, out float biasCoeff) {
	#ifdef EXTENDED_SHADOW_DISTANCE
		vec2 pos = abs(position.xy * 1.165);
		biasCoeff = pow(pow(pos.x, 8) + pow(pos.y, 8), 1.0 / 8.0);
	#else
		biasCoeff = length(position.xy);
	#endif
	
	biasCoeff = biasCoeff * SHADOW_MAP_BIAS + (1.0 - SHADOW_MAP_BIAS);
	
	position.xy /= biasCoeff;
	position.z /= 4.0;
	
	return position;
}

float GetNormalShading(in vec3 normal, in Mask mask) {
	float shading = max(mask.grass, dot(normal, lightVector));
	      shading = mix(shading, shading * 0.5 + 0.5, mask.leaves);
	
	return shading;
}

float ComputeDirectSunlight(in vec4 position, in float normalShading) {
	if (normalShading <= 0.0) return 0.0;
	
	float biasCoeff;
	
	position = ViewSpaceToWorldSpace(position);
	position = WorldSpaceToShadowSpace(position);
	position = BiasShadowProjection(position, biasCoeff); 
	position = position * 0.5 + 0.5;
	
	if (position.x < 0.0 || position.x > 1.0
	||  position.y < 0.0 || position.y > 1.0
	||  position.z < 0.0 || position.z > 1.0
	    ) return 1.0;
	
	#ifdef SOFT_SHADOWS
		float sunlight = 0.0;
		float spread   = 1.0 * (1.0 - biasCoeff) / shadowMapResolution;
		
		const float range       = 1.0;
		const float interval    = 1.0;
		const float sampleCount = pow(range / interval * 2.0 + 1.0, 2.0);    //Calculating the sample count outside of the for-loop is generally faster.
		
		for (float i = -range; i <= range; i += interval)
			for (float j = -range; j <= range; j += interval)
				sunlight += shadow2D(shadow, vec3(position.xy + vec2(i, j) * spread, position.z)).x;
		
		sunlight /= sampleCount;    //Average the samples by dividing the sum by the sample count.
	#else
		float sunlight = shadow2D(shadow, position.xyz).x;
	#endif
	
	sunlight *= sunlight;    //Fatten the shadow up to soften its penumbra
	
	return sunlight;
}

vec3 GetIndirectLight(in vec2 coord) {
	#ifdef DEFERRED_SHADING
		return texture2D(colortex4, coord).rgb;
	#endif
	
	return vec3(0.0);
}

vec3 EncodeColor(in vec3 color) {    //Prepares the color to be sent through a limited dynamic range pipeline
	return pow(color * 0.001, vec3(1.0 / 2.2));
}

vec3 CalculateShadedFragment(in vec3 diffuse, in Mask mask, in float torchLightmap, in float skyLightmap, in vec3 normal, in vec4 ViewSpacePosition) {
	diffuse = pow(diffuse, vec3(2.2));    //Put diffuse into a linear color space (diffuse should not be previously gamma-adjusted)
	
	
	Shading shading;
	shading.normal = GetNormalShading(normal, mask);
	
	shading.sunlight  = shading.normal;
	shading.sunlight *= ComputeDirectSunlight(ViewSpacePosition, shading.normal);
	
	shading.torchlight = 1.0 - pow(torchLightmap, 4.0);
	shading.torchlight = 1.0 / pow(shading.torchlight, 2.0) - 1.0;
	
	shading.skylight = pow(skyLightmap, 4.0);
	
	shading.ambient = 1.0;
	
	
	Lightmap lightmap;
	lightmap.sunlight = shading.sunlight * colorSunlight;
	
	lightmap.skylight = shading.skylight * sqrt(colorSkylight);
	
	lightmap.ambient = shading.ambient * vec3(1.0);
	
	lightmap.indirect = GetIndirectLight(texcoord);
	
	lightmap.torchlight = shading.torchlight * vec3(1.00, 0.25, 0.05);
	
	
	vec3 composite = (
	    lightmap.sunlight   * 4.5
	+   lightmap.skylight   * 0.4
	+   lightmap.indirect
	+   lightmap.ambient    * 0.005
	+   lightmap.torchlight
	    ) * diffuse;
	
	return EncodeColor(composite);
}