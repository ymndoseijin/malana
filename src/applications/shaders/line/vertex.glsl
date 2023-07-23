#version 330 core
layout (location = 0) in vec3 aPos;
layout (location = 1) in vec3 aColor;

uniform mat4 transform;

uniform vec2 in_resolution;
uniform float time;
uniform float bright;

out vec3 Color;

void main()
{
   vec3 position = aPos;
   //position /= sqrt(position.x*position.x+position.y*position.y+position.z*position.z);
   gl_Position = transform*vec4(position, 1.0);
   Color = aColor;
}
