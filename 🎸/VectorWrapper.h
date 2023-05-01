#import <metal_stdlib>

const constant float FLOAT_EPSILON = 1e-4f;

typedef float3 Color;
typedef float3 Location;
typedef float3 Direction;

namespace Colors {
static inline const Color black() { return {0, 0, 0}; }
static inline const Color white() { return {1, 1, 1}; }
static inline const Color pink() { return {1, 0, 1}; }
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


inline Color aces_approx(Color v) {
    float a = 2.51;
    float b = 0.03;
    float c = 2.43;
    float d = 0.59;
    float e = 0.14;
    auto corrected = (v*(a*v+b))/(v*(c*v+d)+e);

    return {max(0, min(1, pow(corrected, 1 / 2.2)))};
}

inline Color tone_map(Color c, float3 mapValues, float gammaCorrection) {

    float intensity = mapValues[0]*c[0]+mapValues[1]*c[1]+mapValues[2]*c[2];
    float toneOperator = intensity/(1.0+intensity);
    float scale = toneOperator/intensity;
    float3 scaledColor = scale*c;
    float3 clamped = clamp(scaledColor, 0.f,1.f);
    float3 gammaVals = pow(clamped, gammaCorrection);
    return gammaVals;
}
