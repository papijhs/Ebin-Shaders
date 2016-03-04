#version 120

uniform sampler2D		texture;
uniform sampler2D		lightmap;

varying vec4	color;
varying vec2	texcoord;
varying vec2	lightCoord;

void main() {
	gl_FragColor = color * texture2D(texture, texcoord) * vec4(texture2D(lightmap, lightCoord).rgb, 1.0);
}
