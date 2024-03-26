#version 450

layout (binding = 0) uniform GlobalUBO {
   float time;
   vec2 in_resolution;
} global_ubo;


layout (location = 0) in vec2 uv;
layout (location = 0) out vec4 FragColor;

layout(binding = 1) uniform sampler2D texSampler;

void main()
{
   vec4 col = texture(texSampler, uv);
   FragColor = col;
}
