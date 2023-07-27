#version 330 core
out vec4 FragColor;

in vec2 TexCoord;
in vec3 Normal;
in vec3 Pos;
in float Time;

uniform sampler2D texture0;
uniform vec3 real_cam_pos;
uniform float fog;

void main()
{

   float depth = LinearizeDepth(gl_FragCoord.z) / far / fog; // divide by far for demonstration

   vec3 lightDir = normalize(vec3(0,0,0) - Pos - real_cam_pos);
   vec3 norm = normalize(Normal);

   float diff = max(dot(norm, lightDir), 0.0);

   vec3 result = texture(texture0, TexCoord).xyz*(diff+0.1);

   //if (diff < 0.3) result = vec3(0);
   //vec3 fogged = mix(vec3(0.2, 0.2, 0.2), result, smoothstep(1.0, 0.0, depth));

   FragColor = vec4(result, 1.0);
}
