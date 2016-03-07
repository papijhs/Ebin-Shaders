struct Mask {
	float materialIDs;
	float matIDs;
	
	float bit0;
	float bit1;
	float bit2;
	float bit3;
	
	float grass;
	float leaves;
	float sky;
};

struct Shading {     //Contains all the light levels, or light intensities, without any color
	float normal;    //Coefficient of light intensity based on the dot product of the normal vector and the light vector
	float sunlight;
	float skylight;
	float torchlight;
	float ambient;
};

struct Lightmap {    //Contains all the light with color/pigment applied
	vec3 sunlight;
	vec3 skylight;
	vec3 torchlight;
	vec3 ambient;
};