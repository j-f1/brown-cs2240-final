#include <metal_stdlib>
using namespace metal;
using namespace raytracing;

const constant float FLOAT_EPSILON = 1e-4f;

typedef float3 Color;
typedef float3 Location;
typedef float3 Direction;

namespace Colors {
static inline const Color black() { return {0, 0, 0}; }
static inline const Color white() { return {1, 1, 1}; }
static inline const Color pink() { return {1, 0, 1}; }
static inline const Color purple() { return {0.4, 0.2, 0.6}; }
static inline const Color gray(float c) { return {c, c, c}; }
}

inline bool floatEpsEqual(float a, float b) {
    // If the difference between a and b is less than epsilon, they are equal
    return abs(a - b) < FLOAT_EPSILON;
}

inline bool floatEpsEqual(float3 a, float3 b) {
    // If the difference between a and b is less than epsilon, they are equal
    return all(abs(a - b) < FLOAT_EPSILON);
}
