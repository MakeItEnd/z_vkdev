#version 450

// Shader input.
layout(location = 0) in vec3 inColor;

// Output write.
layout(location = 0) out vec4 outFragColor;

void main() {
  // Return red.
  outFragColor = vec4(inColor, 1.0f);
}
