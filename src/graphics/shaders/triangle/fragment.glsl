#version 330 core
out vec4 FragColor;

in vec2 TexCoord;
in vec3 Normal;
in float Time;

uniform sampler2D texture0;
uniform float fog;

float near = 0.1; 
float far  = 2048.0; 
  
float LinearizeDepth(float depth) 
{
    float z = depth * 2.0 - 1.0; // back to NDC 
    return (2.0 * near * far) / (far + near - z * (far - near));	
}

void main()
{

    float depth = LinearizeDepth(gl_FragCoord.z) / far / fog; // divide by far for demonstration

    vec3 lightDirection = normalize(vec3(cos(Time), 0.5, sin(Time)));
    vec3 norm = normalize(Normal);
    vec3 result = texture(texture0, TexCoord).xyz*((max(dot(norm, lightDirection), 0.0))+0.4);
    vec3 fogged = mix(vec3(0.2, 0.2, 0.2), result, smoothstep(1.0, 0.0, depth));

    FragColor = vec4(fogged, 1.0);
}
