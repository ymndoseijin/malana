#version 330 core
out vec4 FragColor;

in vec2 TexCoord;
in vec3 Normal;
in float Time;
in vec3 Pos;

uniform sampler2D texture0;
uniform vec3 real_cam_pos;
uniform vec3 spatial_pos;
uniform vec3 planet_pos;
uniform float fog;
uniform float falloff;

const float RADIUS = 0.15;
float SURFACE = 0.11;


const vec3 coeff = vec3(5.8e-2, 13.6e-2, 33.1e-2)*10;
float FALLOFF = 15;

float dens(vec3 pos) {
   float h = length(pos-spatial_pos)-SURFACE;
   return exp(-h/(RADIUS-SURFACE)*FALLOFF);
}

const float STEPS = 10;

vec2 ray_sphere_intersect(
    vec3 start, // starting position of the ray
    vec3 dir, // the direction of the ray
    float radius // and the sphere radius
) {
    // ray-sphere intersection that assumes
    // the sphere is centered at the origin.
    // No intersection when result.x > result.y
    float a = dot(dir, dir);
    float b = 2.0 * dot(dir, start);
    float c = dot(start, start) - (radius * radius);
    float d = (b*b) - 4.0*a*c;
    if (d < 0.0) return vec2(1e5,-1e5);
    return vec2(
        (-b - sqrt(d))/(2.0*a),
        (-b + sqrt(d))/(2.0*a)
    );
}

vec3 transmittance(vec3 start, vec3 end) {
   vec3 dir = normalize(end-start);

   float DS = length(end-start)/STEPS;

   float b0 = 0.4;
   float res = 0;

   for (int i = 0; i < STEPS; i++) {
      float dens = dens(start);
      res += dens*DS;
      start += dir*DS;
   }
   return exp(-coeff*res);
}

float distance(float r, vec3 center, vec3 pos) {
   return length(pos-center)-r;
}

void main()
{
   vec3 position = Pos;
   vec3 dir = normalize(position);

   vec2 hit = ray_sphere_intersect(-spatial_pos, dir, 1.0);

   vec3 start = dir*hit.x;
   vec3 end = dir*hit.y;
   float DS = length(end-start)/STEPS;

   vec3 res = vec3(0);

   vec3 sun_pos = normalize(-planet_pos)*3*0.1+spatial_pos;

   for (int i = 0; i < STEPS; i++) {
      start += dir*DS;

      float h = length(start);
      vec3 sunDiff = sun_pos-start;
      float dens = dens(start);
      float b0 = 1;
      vec3 Bh = dens*coeff;
      float phase = 3/(16*PI)*(1+pow(dot(dir, normalize(sunDiff)), 2));
      vec3 Lsun = 7*transmittance(start, sun_pos)*phase*Bh;
      res += transmittance(position, start)*Lsun*DS;
   }

   //FragColor = vec4(vec3(hit.y-hit.x), 1.0);
   //FragColor = vec4(vec3(dens(dir*hit.x)*100), 1.0);
   FragColor = vec4(1.0);
}
