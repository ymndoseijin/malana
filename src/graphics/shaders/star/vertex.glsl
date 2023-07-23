#version 330 core
layout (location = 0) in vec3 aPos;
layout (location = 1) in vec2 aTexCoord;

uniform mat4 transform;
uniform mat4 model;

uniform vec2 in_resolution;
uniform float time;
uniform float bright;
uniform vec3 pos;

out vec2 TexCoord;

void main()
{
   vec3 position = aPos;
   vec4 vert = transform*vec4(position, 1.0);
   gl_Position = vert;


   TexCoord = aTexCoord;
}
