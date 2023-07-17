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
   vec3 position = aPos;
   position /= mix(sqrt(position.x*position.x+position.y*position.y+position.z*position.z), 1, cos(time*0.5)+1);
   vec4 vert = transform*vec4(position, 1.0);
   gl_Position = vert;
   TexCoord = aTexCoord;
}
