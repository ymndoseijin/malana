#version 330 core
out vec4 FragColor;

in vec2 TexCoord;

uniform sampler2D texture0;

float near = 0.1; 
float far  = 2048.0; 

void main()
{
   vec2 pos = (TexCoord-0.5)*2;
   vec3 color = vec3(1.0, 1.0, 1.0);
   FragColor = mix(vec4(color, 1.0), vec4(0.0), (pos.x*pos.x+pos.y*pos.y));
}
