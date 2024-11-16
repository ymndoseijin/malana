#version 450

layout (binding = 0) uniform SpatialUBO {
   float time;
   vec2 in_resolution;
} spatial_ubo;

layout (binding = 1) uniform RectUBO {
   vec2 size;
   vec2 position;
   vec4 color;
} rect_ubo;

layout (location = 0) in vec3 aPos;
layout (location = 1) in vec2 aTexCoord;
layout (location = 0) out vec2 uv;

void main()
{
   vec4 position = vec4(aPos, 1.0);
   position *= vec4(rect_ubo.size, 1, 1);
   position += vec4(rect_ubo.position, 0, 0);

   position /= vec4(spatial_ubo.in_resolution / 2, 1, 1);
   position.xy -= 1;
   position.z = 0;

   gl_Position = position;
   uv = aTexCoord;
}
