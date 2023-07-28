#version 330 core
layout (location = 0) in vec3 aPos;
layout (location = 1) in vec2 aTexCoord;
layout (location = 2) in vec3 aNormal;

uniform mat4 transform;
uniform mat3 affine;

uniform vec2 in_resolution;
uniform float time;
uniform float bright;
uniform vec3 pos;
uniform vec3 real_cam_pos;
uniform vec3 size;

out vec2 TexCoord;
out vec3 Normal;
out float Time;
out vec3 Pos;

void main()
{
   vec3 position = aPos*size*(in_resolution.x/size.x)*2;
   Pos = vec3((vec2(position)/in_resolution)-1.0, 0.0);
   gl_Position = vec4(Pos, 1.0);
   TexCoord = aTexCoord;
   Time = time;
   Normal = aNormal;
}
