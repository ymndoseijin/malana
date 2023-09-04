#version 330 core
out vec4 FragColor;
  
in vec3 Color;
in vec2 FragCoord;

void main()
{
    float depth = LinearizeDepth(gl_FragCoord.z) / far * 30 ; // divide by far for demonstration
    vec3 color = mix(vec4(0, 0, 0, 1.0), vec4(Color, 1.0), smoothstep(1.0, 0.0, depth));
    if (distance(FragCoord) < 1) {
       FragColor = color;
    } else {
       FragColor = vec3(0.0);
    }
}
