#version 330 core
#define FONT_SIZE 15
out vec4 FragColor;

in vec2 iResolution;
in vec2 TexCoord;
in float iTime;

uniform sampler2D texture0;

void main()
{

   float time = iTime;
   ivec2 textureSize2d = textureSize(texture0,0);
   float depth = LinearizeDepth(gl_FragCoord.z) / far * 60; // divide by far for demonstration

   vec2 fc = TexCoord*FONT_SIZE;
   ivec2 coords = ivec2(fc.x-2, fc.y);
   vec4 color = texelFetch(texture0, coords, 0);

   FragColor = mix(vec4(0.2, 0.2, 0.2, 1.0), color, smoothstep(1.0, 0.0, depth));
}
