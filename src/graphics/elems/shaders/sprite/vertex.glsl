#version 330 core
layout (location = 0) in vec3 aPos;
layout (location = 1) in vec2 aTexCoord;

uniform mat3 transform;
uniform vec2 in_resolution;
uniform float time;

out vec2 TexCoord;
out float Time;
out vec3 Pos;

void main()
{
   vec3 position = transform*aPos;
   position /= vec3(in_resolution/2, 1);
   position.xy -= 1;
   position.z = 0.4;

   vec4 vert = vec4(position, 1.0);
   Pos = position;
   gl_Position = vert;
   TexCoord = aTexCoord;
   Time = time;
}
