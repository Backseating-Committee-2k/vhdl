#version 450

layout(location = 0) out vec2 texCoord;

vec2 positions[4] = vec2[]
(
	vec2(-1.0, -1.0),
	vec2(1.0, -1.0),
	vec2(-1.0, 1.0),
	vec2(1.0, 1.0)
);

void main()
{
	gl_Position = vec4(positions[gl_VertexIndex], 0.0, 1.0);
	texCoord = positions[gl_VertexIndex] / 2.0 + vec2(0.5, 0.5);
}
