#import "common.h"

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

inline bool diagonalStripe(uint2 tid, bool flip, const constant Uniforms &uniforms, int interval = 6, int width = 2) {
    return flip
        ? abs(int(tid.x) % interval - int(tid.y) % interval) < width
        : abs(int(uniforms.settings.imageWidth - tid.x) % interval - int(tid.y) % interval) < width;
}

inline float4 applyStripe(bool isStripe) {
    return float4(isStripe ? Colors::pink() * 0.8 : Colors::purple() * 1.1, 1);
}

inline void accumulate(const thread float4 &sample, thread float4 &accumulator, uint2 tid, const constant Uniforms &uniforms) {
    if (accumulator.a > 0) return;

//    if (any(isnan(sample))) {
//        /* \\\\ = nan */
//        accumulator = applyStripe(diagonalStripe(tid, true, uniforms));
//    } else if (any(isinf(sample))) {
//        /* |||| = inf */
//        accumulator = applyStripe(abs(int(tid.x) % 6) < 2);
//    } else if (any(sample < -0.01)) {
//        /* //// = < 0 */
//        accumulator = applyStripe(diagonalStripe(tid, false, uniforms));
//    } else {
        accumulator.rgb += sample.rgb;
//    }
}

kernel void flattenKernel(
    uint2                               tid                       [[thread_position_in_grid]],
    constant Uniforms &                 uniforms                  [[buffer(BufferIndexUniforms)]],
    texture3d<float, access::read>      srcTex                    [[texture(TextureIndexSrc)]],
    texture2d<uint, access::write>      dstTex                    [[texture(TextureIndexDst)]]
) {
    float4 result = 0.f;
    for (uint z = 0; z < srcTex.get_depth(); z++) {
        accumulate(srcTex.read(uint3(tid, z)), result, tid, uniforms);
        if (result.a > 0) {
            uint3 crunched = uint3(result.rgb * 255);
            dstTex.write(uint4(crunched, 255), tid);
            return;
        }
    }

    result /= srcTex.get_depth();
//    float3 toneMapped = tone_map(result.rgb, uniforms.settings.toneMap, uniforms.settings.gammaCorrection);
    // TODO: make this an optional color mode
    // float3 toneMapped = aces_approx(result.rgb);
    uint3 crunched = uint3((result.rgb + 1) / 2 * 255);
    dstTex.write(uint4(crunched, 255), tid);
}
