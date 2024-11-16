#version 450

layout (binding = 0) uniform SpatialUBO {
   float time;
   vec2 in_resolution;
} spatial_ubo;

layout (binding = 1) uniform RectUBO {
   vec2 size;
   vec2 position;
   vec4 color;
   float roundness;
} rect_ubo;

layout (location = 0) in vec2 uv;
layout (location = 0) out vec4 frag_color;

void main()
{
   float size = rect_ubo.roundness;
   float aspect = rect_ubo.size.x/rect_ubo.size.y;

   vec2 uv = uv * vec2(aspect, 1.0);

   float fac = aspect / 2.0 * size;
   vec2 tr = uv - vec2(aspect - fac, 1.0 - fac);
   vec2 tl = uv - vec2(fac, 1.0 - fac);
   vec2 br = uv - vec2(aspect - fac, fac);
   vec2 bl = uv - vec2(fac, fac);

   if (length(tr) > fac && tr.x > 0.0 && tr.y > 0.0 ||
         length(tl) > fac && tl.x < 0.0 && tl.y > 0.0 ||
         length(br) > fac && br.x > 0.0 && br.y < 0.0 ||
         length(bl) > fac && bl.x < 0.0 && bl.y < 0.0
      ) {
      frag_color = vec4(0.0);
   } else {
      frag_color = rect_ubo.color;
   }
   //frag_color = vec4(uv, 0.0, 1.0);
}
