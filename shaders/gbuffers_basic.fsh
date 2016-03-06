#version 120

/* DRAWBUFFERS:2 */

varying vec3 color;

void main() {
	gl_FragData[0] = vec4(color.rgb, 1.0);
}