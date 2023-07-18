#version 330 core
out vec4 FragColor;

in vec2 TexCoord;
in vec3 Normal;
in float Time;

uniform sampler2D texture0;

float near = 0.1; 
float far  = 2048.0; 
  
float LinearizeDepth(float depth) 
{
    float z = depth * 2.0 - 1.0; // back to NDC 
    return (2.0 * near * far) / (far + near - z * (far - near));	
}

void main()
{

    float depth = LinearizeDepth(gl_FragCoord.z) / far * 60; // divide by far for demonstration

    vec3 lightDirection = normalize(vec3(cos(Time), 0.5, sin(Time)));
    vec3 norm = normalize(Normal);
    vec3 color = mix(vec3(0.2, 0.2, 0.2), texture(texture0, TexCoord).xyz, smoothstep(1.0, 0.0, depth));
    vec3 result = color*((max(dot(norm, lightDirection), 0.0))+0.4);

    FragColor = vec4(result, 1.0);
}
