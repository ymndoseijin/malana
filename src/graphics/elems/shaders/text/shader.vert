#version 450
#define FONT_SIZE 15

layout (binding = 0) uniform SpatialUBO {
   float time;
   vec2 in_resolution;
} spatial_ubo;

layout (binding = 1) uniform OtherUBO {
   vec3 pos;
} other_ubo;

layout (location = 0) in vec3 aPos;
layout (location = 1) in vec2 aTexCoord;
layout (location = 0) out vec2 uv;

void main()
{
   vec3 pixel_scale = vec3(1/spatial_ubo.in_resolution.x, 1/spatial_ubo.in_resolution.y, 1);

   vec3 position = (aPos+other_ubo.pos)*2*pixel_scale;
   position.xy -= 1.;
   position.z = 0;
   vec4 vert = vec4(position, 1.0);

   gl_Position = vert;


   uv = aTexCoord;
}
