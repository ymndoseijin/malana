#version 330 core
layout (location = 0) in vec3 aPos;
layout (location = 1) in vec2 aTexCoord;
layout (location = 2) in vec3 aNormal;

uniform mat4 transform;
uniform mat4 model;
uniform vec3 real_cam_pos;

uniform vec2 in_resolution;
uniform float time;
uniform float bright;
uniform vec3 pos;

out vec2 TexCoord;
out vec3 Normal;
out float Time;
out vec3 Pos;

void main()
{
   vec3 position = aPos;
   mat3 norm_matrix = transpose(inverse(mat3(model)));
   //position /= sqrt(position.x*position.x+position.y*position.y+position.z*position.z);

   Pos = vec3(model * vec4(position, 1.0))-real_cam_pos;

   gl_Position = transform * (model * vec4(position, 1.0)-vec4(real_cam_pos, 0.0));
   TexCoord = aTexCoord;
   Time = time;
   Normal = norm_matrix*aNormal;
}
