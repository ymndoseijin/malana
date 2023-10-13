#version 330 core
out vec4 FragColor;

in vec2 TexCoord;
in float Time;
in vec3 Pos;

uniform vec4 color;
uniform vec3 real_cam_pos;
uniform vec3 spatial_pos;
uniform float fog;

void main()
{
   FragColor = color;
}
