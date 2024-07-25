#version 450


#define motor     mat2x4  // [ [s, e23, e31, e12], [e01, e02, e03, e0123] ]

struct Multivector {
   vec4 mul0;
   vec4 mul1;
};


layout (binding = 0) uniform GlobalUBO {
   float time;
   vec2 in_resolution;
   motor a;
   motor b;
} global_ubo;


layout (location = 0) in vec2 in_fragCoord;
layout (location = 0) out vec4 fragColor;

float iTime = global_ubo.time;
vec2 iResolution = global_ubo.in_resolution;
vec2 fragCoord = in_fragCoord * iResolution;

// changes above

motor gp_mm( motor a, motor b ) {
   return motor(
      a[0].x*b[0].x   - dot(a[0].yzw, b[0].yzw), 
      a[0].x*b[0].yzw + b[0].x*a[0].yzw + cross(b[0].yzw, a[0].yzw),
      a[0].x*b[1].xyz + b[0].x*a[1].xyz + cross(b[0].yzw, a[1].xyz) + cross(b[1].xyz, a[0].yzw) - b[1].w*a[0].yzw - a[1].w*b[0].yzw, 
      a[0].x*b[1].w + b[0].x*a[1].w + dot(a[0].yzw, b[1].xyz) + dot(a[1].xyz, b[0].yzw)
   );
}

Multivector mm(Multivector a, Multivector b) {
   Multivector res = Multivector(vec4(0), vec4(0));

   res.mul0 += a.mul0.xxxx * b.mul0.xyzw * vec4(1, 1, 1, 1);
   res.mul0 += a.mul1.zzww * b.mul1.zwyx * vec4(-1, -1, 1, -1);
   res.mul0 += a.mul1.xwyx * b.mul1.xzww * vec4(-1, -1, 1, -1);

   res.mul0.yzw += a.mul1.xxy * b.mul0.zyy * vec3(1, -1, -1);
   res.mul0.yzw += a.mul0.yzw * b.mul0.xxx * vec3(1, 1, 1);

   res.mul0.x += a.mul1.y * b.mul1.y * -1.0;

   res.mul0.yzw += a.mul0.zwy * b.mul1.xzy * vec3(-1, -1, 1);
   res.mul0.yzw += a.mul0.wyz * b.mul1.yxz * vec3(-1, 1, 1);
   res.mul0.yzw += a.mul1.yzz * b.mul0.wwz * vec3(1, 1, -1);

   res.mul1 += a.mul0.xxxx * b.mul1.xyzw * vec4(1, 1, 1, 1);
   res.mul1 += a.mul1.xyzy * b.mul0.xxxz * vec4(1, 1, 1, -1);

   res.mul1.xyz += a.mul1.yzx * b.mul1.zxy * vec3(-1, -1, -1);
   res.mul1.xyz += a.mul1.zxy * b.mul1.yzx * vec3(1, 1, 1);

   res.mul1.w += a.mul1.w * b.mul0.x * 1.0;
   res.mul1.w += a.mul0.y * b.mul1.z * 1.0;
   res.mul1.w += a.mul0.z * b.mul1.y * -1.0;
   res.mul1.w += a.mul0.w * b.mul1.x * 1.0;
   res.mul1.w += a.mul1.x * b.mul0.w * 1.0;
   res.mul1.w += a.mul1.z * b.mul0.y * 1.0;

   return res;
}

void main() {
   motor res = gp_mm(global_ubo.a, global_ubo.b);

   fragColor = vec4(dot(res[0], res[1])*cross(res[0].ywz, res[1].ywz), res[1].w)*res[0]*res[1];
}
