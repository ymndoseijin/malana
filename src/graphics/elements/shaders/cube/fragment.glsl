#version 330 core
out vec4 FragColor;

in vec2 TexCoord;

uniform sampler2D texture0;

void main()
{
   float depth = LinearizeDepth(gl_FragCoord.z) / far * 60; // divide by far for demonstration
   FragColor = mix(vec4(0.2, 0.2, 0.2, 1.0), texture(texture0, TexCoord), smoothstep(1.0, 0.0, depth));
}
