#version 450

layout (location = 0) in vec3 aPos;
layout (location = 1) in vec2 aTexCoord;
layout (location = 2) in vec3 aNormal;

layout (binding = 0) uniform SpatialUBO {
   float time;
   vec2 in_resolution;
} spatial_ubo;

layout (binding = 1) uniform OtherUBO {
   vec3 spatial_pos;
   mat4 transform;
   vec3 cam_pos;
} other_ubo;


layout (location = 0) out vec2 TexCoord;
layout (location = 1) out vec3 Normal;
layout (location = 2) out float Time;
layout (location = 3) out vec3 Pos;

void main()
{
   vec3 position = aPos;
   vec4 vert = other_ubo.transform*vec4(position-other_ubo.cam_pos, 1.0);
   Pos = position;
   gl_Position = vert;
   TexCoord = aTexCoord;
   Time = spatial_ubo.time;
   Normal = aNormal;
}
