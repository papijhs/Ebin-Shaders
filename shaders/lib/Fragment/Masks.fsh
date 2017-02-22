struct Mask {
	float materialIDs;
	float matIDs;
	
	vec4 bits;
	
	float translucent;
	float hand;
	
	float transparent;
	float water;
	float nightVision;
};

struct Material {
	vec4 albedo;
	vec3 normal;
	float height;
	float f0;
	float pourosity;
	float roughness;
	float AO;
	float emmisiveTranslucence;
};

Material CalculateMaterial(vec2 coord, vec4 color, sampler2D texture, sampler2D normal, sampler2D specular) {
	Material mat;

	mat.albedo = texture2D(texture, coord) * color;
	vec4 normalSample = texture2D(normal, coord);
	vec4 specularSample = texture2D(specular, coord);

	mat.normal = normalize(normalSample.xyz);
	mat.height = normalSample.w;
	mat.f0 = specularSample.x;
	mat.pourosity = specularSample.y;
	mat.roughness = pow2(1.0 - specularSample.z);
	mat.AO = length(normalSample.xyz);
	mat.emmisiveTranslucence = (1.0 - specularSample.w);

	return mat;
}

Material GetMaterial(vec4 decodedMat) {
	Material mat;

	mat.f0 = decodedMat.r;
	mat.roughness = decodedMat.g; 
	mat.emmisiveTranslucence = decodedMat.b; 
	mat.AO = decodedMat.a;

	return mat;
}

#define EmptyMask Mask(0.0, 0.0, vec4(0.0), 0.0, 0.0, 0.0, 0.0, 0.0)

float EncodeMaterialIDs(float materialIDs, vec4 bits) {
	materialIDs += dot(vec4(greaterThan(bits, vec4(0.5))), vec4(128.0, 64.0, 32.0, 16.0));
	
	materialIDs += 0.1;
	materialIDs /= 255.0;
	
	return materialIDs;
}

void DecodeMaterialIDs(io float matID, out vec4 bits) {
	matID *= 255.0;
	
	bits = mod(vec4(matID), vec4(256.0, 128.0, 64.0, 32.0));
	
	bits = vec4(greaterThanEqual(bits, vec4(128.0, 64.0, 32.0, 16.0)));
	
	matID -= dot(bits, vec4(128.0, 64.0, 32.0, 16.0));
}

float GetMaterialMask(float mask, float materialID) {
	return 1.0 - clamp01(abs(materialID - mask));
}

Mask CalculateMasks(float materialIDs) {
	Mask mask;
	
	mask.materialIDs = materialIDs;
	mask.matIDs      = materialIDs;
	
	DecodeMaterialIDs(mask.matIDs, mask.bits);
	
	mask.translucent = GetMaterialMask(2, mask.matIDs);
	mask.hand        = GetMaterialMask(5, mask.matIDs);
	
	mask.transparent = mask.bits.x;
	mask.water       = mask.bits.y;
	mask.nightVision = mask.bits.z;
	
	return mask;
}
