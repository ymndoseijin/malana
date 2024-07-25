#version 450
#define FONT_SIZE 15

layout (binding = 0) uniform SpatialUBO {
   float time;
   vec2 in_resolution;
} spatial_ubo;

layout (binding = 1) uniform OtherUBO {
   vec3 pos;
} other_ubo;

layout (location = 0) in vec2 uv;
layout (location = 0) out vec4 FragColor;

layout(binding = 2) uniform sampler2D texSampler;

void main()
{

   float time = spatial_ubo.time;
   ivec2 textureSize2d = textureSize(texSampler,0);

   vec2 fc = uv*FONT_SIZE;
   ivec2 coords = ivec2(fc.x-2, fc.y);
   vec4 color = texelFetch(texSampler, coords, 0);

   FragColor = color;
}
