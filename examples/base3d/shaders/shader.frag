#version 450
#define max_lights 256
#define PI 3.14159265359

layout (location = 0) out vec4 out_color;

layout (location = 0) in vec2 in_uv;
layout (location = 1) in vec3 in_normal;
layout (location = 2) in vec3 in_pos;

layout (binding = 0) uniform GlobalUBO {
   float time;
   vec2 in_resolution;
} global_ubo;

struct Light {
   vec3 pos;
   vec3 intensity;
};

layout (binding = 1) uniform SpatialUBO {
   vec3 pos;
   int light_count;
   Light lights[max_lights];
} spatial_ubo;

layout (binding = 2) uniform samplerCube cubemap;

layout (push_constant) uniform Constants {
   vec3 cam_pos;
   mat4 cam_transform;
} constants;

float chi(float n) {
   return n < 0 ? -n : n;
}

float G1(vec3 n, vec3 v, vec3 m, float a2) {
   float a = acos(dot(n, v));
   float tan_v = tan(a);
   return chi(dot(v, m)/dot(v, n)) * 2 / (1 + sqrt(1 + a2 * tan_v * tan_v));
}

void main() {
   vec3 total_val = vec3(0);

   float a = 0.05;
   float metallic = 0;
   vec3 albedo = vec3(0,0,1);

   float a2 = a * a;
   vec3 n = normalize(in_normal);

   vec3 f0 = vec3(0.04); 
   f0 = mix(f0, albedo, metallic);

   vec3 v = normalize(constants.cam_pos - in_pos);

   for (int i = 0; i < spatial_ubo.light_count; i++) {
      Light light = spatial_ubo.lights[i];
      float dist = length(light.pos - in_pos);
      vec3 radiance = light.intensity / (dist * dist);

      vec3 l = normalize(light.pos - in_pos);
      vec3 h = normalize(v + l);

      float nh = max(dot(n, h), 0);
      float denom = (1 + nh * nh * (a2-1));

      float d = a2 / (PI * denom * denom);

      float g = G1(n, v, h, a2) * G1(n, l, h, a);

      float hv = max(dot(h, v), 0);
      vec3 f = f0 + (1 - f0) * pow(clamp(1 - hv, 0, 1), 5.0);

      vec3 ks = f;
      vec3 kd = vec3(1) - ks;
      kd *= 1 - metallic;

      float nl = max(dot(n, l), 0.01);
      float nv = max(dot(n, v), 0.01);
      vec3 light_val = kd * albedo/PI + ks * (d * f * g/(4 * nv * nl));

      light_val = light_val * radiance * nl;
      total_val += light_val;
   }

   vec3 res = total_val;
   res = pow(res, vec3(1 / 2.2));
   res = texture(cubemap, reflect(normalize(in_pos - constants.cam_pos), n)).rgb;
   out_color = vec4(res, 1);
}
