#define SHADOW_MAP_BIAS 0.8
#define EXTENDED_SHADOW_DISTANCE

vec4 ViewSpaceToWorldSpace(in vec4 viewSpacePosition) {
	return gbufferModelViewInverse * viewSpacePosition;
}

vec4 WorldSpaceToShadowSpace(in vec4 worldSpacePosition) {
	return shadowProjection * shadowModelView * worldSpacePosition;
}

vec4 BiasWorldPosition(in vec4 position) {
	position = shadowModelView * position;
	
	float dist = length((shadowProjection * position).xy);
	
	#ifdef EXTENDED_SHADOW_DISTANCE
		vec2 pos = abs((shadowProjection * position).xy * 1.165);
		dist = pow(pow(pos.x, 8) + pow(pos.y, 8), 1.0 / 8.0);
	#endif
	
	position.x += 0.5 * dist * SHADOW_MAP_BIAS * mix(1.0, -1.0, float(mod(sunAngle, 0.5) > 0.25));
	position = shadowModelViewInverse * position;
	
	return position;
}

vec4 BiasShadowProjection(in vec4 position) {
	float dist = length(position.xy);
	
	#ifdef EXTENDED_SHADOW_DISTANCE
		vec2 pos = abs(position.xy * 1.165);
		dist = pow(pow(pos.x, 8) + pow(pos.y, 8), 1.0 / 8.0);
	#endif
	
	float distortFactor = (1.0 - SHADOW_MAP_BIAS) + dist * SHADOW_MAP_BIAS;
	
	position.xy /= distortFactor;
	
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
	
	position = ViewSpaceToWorldSpace(position);
//	position = BiasWorldPosition(position);
	position = WorldSpaceToShadowSpace(position);
	position = BiasShadowProjection(position); 
	position = position * 0.5 + 0.5;
	
	if (position.x < 0.0 || position.x > 1.0
	||  position.y < 0.0 || position.y > 1.0
	||  position.z < 0.0 || position.z > 1.0
	    ) return 1.0;
	
	float sunlight = shadow2D(shadow, position.xyz).x;
	      sunlight = pow(sunlight, 2.0);    //Fatten the shadow up to soften its penumbra
	
	return sunlight;
}

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

void CalculateMasks(inout Mask mask, in float materialIDs) {
	mask.materialIDs = materialIDs;
	mask.matIDs      = mask.materialIDs;
	
	DecodeMaterialIDs(mask.matIDs, mask.bit0, mask.bit1, mask.bit2, mask.bit3);
	
	mask.grass  = GetMaterialMask(2, mask.matIDs);
	mask.leaves = GetMaterialMask(3, mask.matIDs);
	mask.sky    = GetMaterialMask(255, mask.matIDs);
}

vec3 CalculateShading(in vec3 diffuse, in Mask mask, in float torchLightmap, in float skyLightmap, in vec3 normal, in vec4 ViewSpacePosition) {
	Shading shading;
	shading.normal = 1.0;
	
	shading.sunlight  = shading.normal;
	shading.sunlight *= ComputeDirectSunlight(ViewSpacePosition, shading.normal);
	
	shading.torchlight = 1.0 - pow(torchLightmap, 4.0);
	shading.torchlight = 1.0 / pow(shading.torchlight, 2.0) - 1.0;
	
	shading.skylight = pow(skyLightmap, 4.0);
	
	shading.ambient = 1.0;
	
	
	Lightmap lightmap;
	lightmap.sunlight = shading.sunlight * vec3(1.0);
	
	lightmap.torchlight = shading.torchlight * vec3(1.0, 0.25, 0.05);
	
	lightmap.skylight = shading.skylight * colorSkylight;
	
	lightmap.ambient = shading.ambient * vec3(1.0);
	
	
	vec3 composite = (
	    lightmap.sunlight   * 4.0
	+   lightmap.torchlight
	+   lightmap.skylight   * 0.4
	+   lightmap.ambient    * 0.003
	    ) * diffuse;
	
	return composite;
}

vec3 Tonemap(in vec3 color) {
	return pow(color / (color + vec3(0.6)), vec3(1.0 / 2.2));
}

vec3 Uncharted2Tonemap(in vec3 color) {
	const float A = 0.15, B = 0.5, C = 0.1, D = 0.2, E = 0.02, F = 0.3, W = 11.2;
	const float whiteScale = 1.0 / (((W * (A * W + C * B) + D * E) / (W * (A * W + B) + D * F)) - E / F);
	const float ExposureBias = 2.3;
	
	vec3 curr = ExposureBias * color;
	     curr = ((curr * (A * curr + C * B) + D * E) / (curr * (A * curr + B) + D * F)) - E / F;
	
	color = curr * whiteScale;
	
	return pow(color, vec3(1.0 / 2.2));
}