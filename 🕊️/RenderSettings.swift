import Foundation

extension RenderSettings: Equatable {
    static let `default` = RenderSettings(
        diffuseOn: true,
        mirrorOn: true,
        // refractionOn: true,
        // glossyOn: true,
        subsurfaceScatteringOn: true,
        singleSSOn: true,
        diffusionSSOn: true,
        ssSigma_s: 5.47,
        ssSigma_a: SIMD3<Float>(0.0002, 0.0028, 0.0163),//SIMD3<Float>(0.01, 0.1, 1.0),
        ssEta: 1.3,
        ssG: 0,
        directLightingOn: true,
        directLightingSamples: 2,
        importanceSamplingOn: false,
        // glassTransmittanceOn: true,
        russianRoulette: 0.7,
        samplesPerPixel: 14,
        toneMap: SIMD3<Float>(0.299, 0.587, 0.114),
        gammaCorrection: 1,
        imageWidth: 512,
        imageHeight: 512,
        frameIndex: 0
    )


    var size: CGSize {
        CGSize(width: CGFloat(imageWidth), height: CGFloat(imageHeight))
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        var lhs = lhs, rhs = rhs
        return memcmp(&lhs, &rhs, MemoryLayout<Self>.size) == 0
    }
}
