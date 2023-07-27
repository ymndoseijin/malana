#version 330 core
out vec4 FragColor;

in vec2 TexCoord;
in vec3 Normal;
in float Time;
in vec3 Pos;

uniform sampler2D texture0;
uniform vec3 real_cam_pos;
uniform vec3 spatial_pos;
uniform float fog;

const float RADIUS = 0.2*1.1;
const float SURFACE = 0.2;


vec3 CENTER = spatial_pos;

const vec3 coeff = vec3(5.8e-2, 13.6e-2, 33.1e-2)*10;
const float FALLOFF = 4.0;

float dens(vec3 pos) {
   float h = length(pos-spatial_pos)-SURFACE;
   return exp(-h/(RADIUS-SURFACE)*FALLOFF);
}

const float STEPS = 19;

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
   vec3 dir = normalize(position-real_cam_pos);

   vec3 start = position;
   vec3 end = position+dir;
   float DS = length(end-start)/STEPS;

   vec3 res = vec3(0);

   vec3 sun_pos = vec3(0.0, 0.0, 0.0);

   for (int i = 0; i < STEPS; i++) {
      start += dir*DS;
      if (length(start-spatial_pos) < SURFACE) {
         res = vec3(0);
         break;
      }

      float h = length(start);
      vec3 sunDiff = sun_pos-start;
      float dens = dens(start);
      float b0 = 1;
      vec3 Bh = dens*coeff;
      float phase = 3/(16*PI)*(1+pow(dot(dir, normalize(sunDiff)), 2));
      vec3 Lsun = 15*transmittance(start, sunDiff)*phase*Bh;
      res += transmittance(position, start)*Lsun*DS;
   }

   res *= 4;

   FragColor = vec4(res, length(res));
   //FragColor = vec4(1.0);
}
