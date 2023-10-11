#version 330 core
out vec4 FragColor;
  
in vec3 Color;

void main()
{
    float depth = LinearizeDepth(gl_FragCoord.z) / far ; // divide by far for demonstration
    FragColor = mix(vec4(0.2, 0.2, 0.2, 1.0), vec4(Color, 1.0), smoothstep(1.0, 0.0, depth));;
}
