#version 330 core
out vec4 FragColor;

in vec2 TexCoord;
in vec3 Normal;
in float Time;
in vec3 Pos;

uniform sampler2D texture0;
uniform vec3 real_cam_pos;
uniform vec3 spatial_pos;
uniform float fog;

void main()
{
   FragColor = vec4(texture(texture0, TexCoord).xyz,1.0);
}

