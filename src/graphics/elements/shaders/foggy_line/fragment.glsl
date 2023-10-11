#version 330 core
out vec4 FragColor;
  
in vec3 Color;

void main()
{
    float depth = LinearizeDepth(gl_FragCoord.z) / far * 30 ; // divide by far for demonstration
    FragColor = mix(vec4(0, 0, 0, 1.0), vec4(Color, 1.0), smoothstep(1.0, 0.0, depth));;
}
