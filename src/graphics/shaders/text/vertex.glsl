#version 330 core
#define FONT_SIZE 15

layout (location = 0) in vec3 aPos;
layout (location = 1) in vec2 aTexCoord;

uniform vec2 in_resolution;
uniform float time;
uniform float bright;
uniform vec3 pos;

out vec2 TexCoord;
out vec2 iResolution;
out float iTime;

void main()
{
   iResolution = in_resolution;
   vec3 pixel_scale = vec3(1/iResolution.x, 1/iResolution.y, 1);

   vec3 position = (aPos+pos)*2*pixel_scale;
   position.xy -= 1.;
   position.z = 0;
   vec4 vert = vec4(position, 1.0);

   gl_Position = vert;


   TexCoord = aTexCoord;
   iTime = time;
}
