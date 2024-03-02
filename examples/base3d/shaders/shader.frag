#version 450
layout (location = 0) out vec4 FragColor;

layout (location = 0) in vec2 TexCoord;
layout (location = 1) in vec3 Normal;
layout (location = 2) in float Time;
layout (location = 3) in vec3 Pos;

layout (binding = 0) uniform SpatialUBO {
   float time;
   vec2 in_resolution;
} spatial_ubo;

layout (binding = 1) uniform OtherUBO {
   vec3 spatial_pos;
   mat4 transform;
   vec3 cam_pos;
} other_ubo;

void main()
{
   FragColor = vec4(TexCoord, 0.0, 1.0);
}
