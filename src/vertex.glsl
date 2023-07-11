#version 330 core
layout (location = 0) in vec3 aPos;
layout (location = 1) in vec2 aTexCoord;

uniform mat4 transform;

uniform vec2 in_resolution;
uniform float time;
uniform float bright;

out vec2 TexCoord;

void main()
{
   vec3 pos = aPos-vec3(0.0, 0.0, 6.0);
   vec4 vert = transform*vec4(pos, 1.0);
   gl_Position = vert;


   TexCoord = aTexCoord;
}
