#version 450
#extension GL_EXT_nonuniform_qualifier : require

layout (binding = 0) uniform SpatialUBO {
   float time;
   vec2 in_resolution;
} spatial_ubo;

layout (binding = 1) uniform OtherUBO {
   mat4 transform;
   float opacity;
} other_ubo[];

layout (location = 0) in vec2 uv;
layout (location = 1) flat in int id;

layout (location = 0) out vec4 FragColor;

layout(binding = 2) uniform sampler2D texSampler[];

void main()
{
   vec4 col = texture(texSampler[id], uv);
   col.a *= other_ubo[id].opacity;
   FragColor = col;
}

