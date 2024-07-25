#version 330 core

#define STEPS 100
#define LB 0.001
#define UB 100.
#define DEL 0.001

out vec4 FragColor;

in vec2 TexCoord;
in vec3 Normal;
in vec3 Pos;
in float Time;

uniform sampler2D texture0;
uniform vec3 cam_pos;

uniform vec3 planet_pos;

uniform float fog;

float sphere(vec3 cen, vec3 pos, float rad)
{
    return length(pos-cen)-rad;
}

float dist(vec3 r)
{
    return sphere(planet_pos, r, 1);
}

vec4 ray(vec3 pos, vec3 dir)
{
    vec3 p = pos+dir;
    for (int i = 0; i < STEPS; i++) {
        float r = dist(p);
        
        if (r < LB) {
        
            vec3 normal = vec3(
                dist(p+delta.yxx)-dist(p-delta.yxx),
                dist(p+delta.xyx)-dist(p-delta.xyx),
                dist(p+delta.xxy)-dist(p-delta.xxy)
            );
            
            return vec4(normalize(normal), r);
        } else if (r > UB) {
            return vec3(0.);
        }
        
        p += dir*r;
    }
}

void main()
{

   float depth = LinearizeDepth(gl_FragCoord.z) / far / fog; // divide by far for demonstration

   vec3 lightDir = normalize(vec3(0,0,0) - Pos);
   vec3 norm = normalize(Normal);

   float diff = max(dot(norm, lightDir), 0.0);

   vec3 result = texture(texture0, TexCoord).xyz*(diff+0.1);

   //if (diff < 0.3) result = vec3(0);
   //vec3 fogged = mix(vec3(0.2, 0.2, 0.2), result, smoothstep(1.0, 0.0, depth));

   FragColor = vec4(result, 1.0);
}
