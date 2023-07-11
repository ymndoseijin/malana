#version 330 core
out vec4 FragColor;
  
in vec3 Color;
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
    FragColor = vec4(Color, smoothstep(1.0, 0.0, depth));
}
