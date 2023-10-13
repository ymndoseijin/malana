#version 330 core
layout (location = 0) in vec3 aPos;
layout (location = 1) in vec2 aFragCoord;

uniform mat4 transform;
uniform vec3 cam_pos;

uniform vec2 in_resolution;
uniform float time;
uniform float bright;

out vec2 FragCoord;

void main()
{
   //position /= sqrt(position.x*position.x+position.y*position.y+position.z*position.z);
   gl_Position = vec4(aPos, 1.0);
   FragCoord = aFragCoord;
}
