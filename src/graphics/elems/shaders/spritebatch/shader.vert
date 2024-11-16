#version 450
#extension GL_EXT_nonuniform_qualifier : require

layout (binding = 0) uniform SpatialUBO {
   float time;
   vec2 in_resolution;
} spatial_ubo;

layout (binding = 1) uniform SpriteUBO {
   mat4 transform;
   float opacity;
} sprite_ubo[];

layout (location = 0) in vec3 aPos;
layout (location = 1) in vec2 aTexCoord;

layout (location = 0) out vec2 uv;
layout (location = 1) out uint id;

void main()
{
   vec4 position = sprite_ubo[gl_InstanceIndex].transform*vec4(aPos, 1.0);
   position /= vec4(spatial_ubo.in_resolution/2, 1, 1);
   position.xy -= 1;
   position.z = 0;

   gl_Position = position;
   uv = aTexCoord;
   id = gl_InstanceIndex;
}
