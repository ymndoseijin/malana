#version 450

layout (binding = 0) uniform SpatialUBO {
   float time;
   vec2 in_resolution;
} spatial_ubo;

layout (binding = 1) uniform LineUBO {
   vec4 color;
} line_ubo;

layout (location = 0) in vec3 aPos;
layout (location = 1) in vec2 aTexCoord;
layout (location = 0) out vec2 uv;

void main()
{
   vec4 position = vec4(aPos, 1.0);

   position /= vec4(spatial_ubo.in_resolution / 2, 1, 1);
   position.xy -= 1;
   //position.x *= spatial_ubo.in_resolution.y / spatial_ubo.in_resolution.x;

   //position.z = 0;

   gl_Position = position;
   uv = aTexCoord;
}
