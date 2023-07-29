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

float RADIUS = 1.1;
float SURFACE = 0.9;

const float STEPS = 19;

vec2 ray_sphere_intersect(
    vec3 start, // starting position of the ray
    vec3 dir, // the direction of the ray
    float radius // and the sphere radius
) {
   //start -= CENTER;
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

void main()
{
   FragColor = vec4(vec3(1.0), 0.3);

}
