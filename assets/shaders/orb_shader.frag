#include <flutter/runtime_effect.glsl>

// Minimal orb shader stub.
// The full GPU-animated orb is rendered via CustomPainter in avatar_orb.dart.
// This stub exists to satisfy the pubspec.yaml shader asset declaration.

uniform vec2 uSize;
uniform float uTime;

out vec4 fragColor;

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  vec2 center = vec2(0.5, 0.5);
  float dist = distance(uv, center);

  // Soft glowing circle
  float alpha = smoothstep(0.5, 0.2, dist);
  vec3 cyanColor = vec3(0.0, 0.83, 1.0);

  // Subtle pulse using time
  float pulse = 0.85 + 0.15 * sin(uTime * 3.0);

  fragColor = vec4(cyanColor * alpha * pulse, alpha * pulse);
}
