#version 330 core
out vec4 FragColor;

in vec2 TexCoord;
in float Time;
in vec3 Pos;

uniform sampler2D texture0;
uniform vec3 real_cam_pos;
uniform vec3 spatial_pos;
uniform float fog;
uniform float opacity;

void main()
{
   vec4 col = texture(texture0, TexCoord);
   col.a *= opacity;
   FragColor = col;
}
