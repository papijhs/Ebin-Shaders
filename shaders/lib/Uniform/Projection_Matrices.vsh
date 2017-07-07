uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

flat varying float FOV;

//#define FOV_OVERRIDE

#ifdef FOV_OVERRIDE
	flat varying mat4 projection;
	flat varying mat4 projectionInverse;
	
	#define FOV_DEFAULT  110 // [70 71 72 73 74 75 76 77 78 79 80 81 82 83 84 85 86 87 88 89 90 91 92 93 94 95 96 97 98 99 100 101 102 103 104 105 106 107 108 109 110 111 112 113 114 115 116 117 118 119 120 121 122 123 124 125 126 127 128 129 130 131 132 133 134 135 136 137 138 139 140 141 142 143 144 145 146 147 148 149 150]
	#define FOV_TRUE      90 // [30 31 32 33 34 35 35 36 37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69 70 71 72 73 74 75 76 77 78 79 80 81 82 83 84 85 86 87 88 89 90 91 92 93 94 95 96 97 98 99 100 101 102 103 104 105 106 107 108 109 110]
	
	void SetupProjection() {
		projection = gbufferProjection;
		projectionInverse = gbufferProjectionInverse;
		
		float gameTrueFOV = degrees(atan(1.0 / gbufferProjection[1].y) * 2.0);
		
		cfloat gameSetFOV = FOV_DEFAULT;
		cfloat targetSetFOV = FOV_TRUE;
		
		FOV = targetSetFOV + (gameTrueFOV - gameSetFOV) * targetSetFOV / gameSetFOV;
		
		projection      = gbufferProjection;
		projection[1].y = 1.0 / tan(radians(FOV) * 0.5);
		projection[0].x = projection[1].y * gbufferProjection[0].x / gbufferProjection[1].y;
		
		
		vec3 i = 1.0 / vec3(diagonal2(projection), projection[3].z);
		
		projectionInverse = mat4(
			i.x, 0.0,  0.0, 0.0,
			0.0, i.y,  0.0, 0.0,
			0.0, 0.0,  0.0, i.z,
			0.0, 0.0, -1.0, projection[2].z * i.z);
	}
	
	#define projMatrix projection
	#define projInverseMatrix projectionInverse
#else
	void SetupProjection() {
		FOV = degrees(atan(1.0 / gbufferProjection[1].y) * 2.0);
	}
	
	#define projMatrix gbufferProjection
	#define projInverseMatrix gbufferProjectionInverse
#endif
