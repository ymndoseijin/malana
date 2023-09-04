#version 330 core
layout (location = 0) in vec3 aPos;
layout (location = 1) in vec2 aTexCoord;
layout (location = 2) in vec3 aNormal;

uniform mat4 transform;

uniform vec2 in_resolution;
uniform float time;
uniform float bright;
uniform vec3 pos;
uniform vec3 cam_pos;

out vec2 TexCoord;
out vec3 Normal;
out float Time;
out vec3 Pos;

void main()
{
   vec3 position = aPos;
   vec4 vert = transform*vec4(position-cam_pos, 1.0);
   Pos = position;
   gl_Position = vert;
   TexCoord = aTexCoord;
   Time = time;
   Normal = aNormal;
}
