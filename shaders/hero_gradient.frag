#include <flutter/runtime_effect.glsl>

uniform float uTime;
uniform vec2  uSize;

out vec4 fragColor;

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;

  // Rotation ~50° (comme rotationZ: 50 dans shadergradient)
  vec2 c = uv - 0.5;
  float a = 0.873;
  vec2 p = vec2(c.x * cos(a) - c.y * sin(a), c.x * sin(a) + c.y * cos(a)) + 0.5;

  float t = uTime * 0.4;

  // Vagues (uFrequency: 5.5, uSpeed: 0.4, uStrength: 4)
  float w1 = sin(p.x * 5.5 + t * 1.5) * 0.5 + 0.5;
  float w2 = sin(p.y * 5.5 - t + p.x * 2.0) * 0.5 + 0.5;
  float w3 = sin((p.x + p.y) * 4.0 + t * 0.8) * 0.5 + 0.5;

  float blend = clamp((w1 * w2 + w3 * 0.5) * 0.65, 0.0, 1.0);

  // color1/2: #000071  color3: #6370e1
  vec3 navy   = vec3(0.0,   0.0,   0.443);
  vec3 purple = vec3(0.388, 0.439, 0.882);

  vec3 col = mix(navy, purple, blend * 0.55);
  col = clamp(col * 0.85, 0.0, 1.0);

  fragColor = vec4(col, 1.0);
}
