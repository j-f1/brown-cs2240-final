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
        // cream:
        ss: .cream,
        directLightingOn: true,
        directLightingSamples: 2,
        importanceSamplingOn: true,
        // glassTransmittanceOn: true,
        russianRoulette: 0.7,
        samplesPerPixel: 14,
        toneMap: SIMD3<Float>(0.299, 0.587, 0.114),
        gammaCorrection: 1 / 2.2,
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

extension SubsurfaceMaterial : Equatable {
    static let all = [
        "Apple": apple,
        "Chicken 1": chicken1,
        "Chicken 2": chicken2,
        "Cream": cream,
        "Ketchup": ketchup,
        "Marble": marble,
        "Potato": potato,
        "Skim Milk": skimMilk,
        "Skin 1": skin1,
        "Skin 2": skin2,
        "Spectralon": spectralon,
        "Whole Milk": wholeMilk
    ]

    static let apple = SubsurfaceMaterial(
        sigma_s_prime: SIMD3<Float>(2.29, 2.39, 1.97),
        sigma_a: SIMD3<Float>(0.0030, 0.0034, 0.046),
        eta: 1.3,
        g: 0.0
    )
    static let chicken1 = SubsurfaceMaterial(
        sigma_s_prime: SIMD3<Float>(0.15, 0.21, 0.38),
        sigma_a: SIMD3<Float>(0.015, 0.077, 0.19),
        eta: 1.3,
        g: 0.0
    )
    static let chicken2 = SubsurfaceMaterial(
        sigma_s_prime: SIMD3<Float>(0.19, 0.25, 0.32),
        sigma_a: SIMD3<Float>(0.018, 0.088, 0.20),
        eta: 1.3,
        g: 0.0
    )
    static let cream = SubsurfaceMaterial(
        sigma_s_prime: SIMD3<Float>(7.38, 5.47, 3.15),
        sigma_a: SIMD3<Float>(0.0002, 0.0028, 0.0163),
        eta: 1.3,
        g: 0
    )
    static let ketchup = SubsurfaceMaterial(
        sigma_s_prime: SIMD3<Float>(0.18, 0.07, 0.03),
        sigma_a: SIMD3<Float>(0.061, 0.97, 1.45),
        eta: 1.3,
        g: 0
    )
    static let marble = SubsurfaceMaterial(
        sigma_s_prime: SIMD3<Float>(2.19, 2.62, 3.00),
        sigma_a: SIMD3<Float>(0.0021, 0.0041, 0.0071),
        eta: 1.5,
        g: 0.0
    )
    static let potato = SubsurfaceMaterial(
        sigma_s_prime: SIMD3<Float>(0.68, 0.70, 0.55),
        sigma_a: SIMD3<Float>(0.0024, 0.0090, 0.12),
        eta: 1.3,
        g: 0.0
    )
    static let skimMilk = SubsurfaceMaterial(
        sigma_s_prime: SIMD3<Float>(0.70, 1.22, 1.90),
        sigma_a: SIMD3<Float>(0.0011, 0.0024, 0.014),
        eta: 1.3,
        g: 0.0
    )
    static let skin1 = SubsurfaceMaterial(
        sigma_s_prime: SIMD3<Float>(0.74, 0.88, 1.01),
        sigma_a: SIMD3<Float>(0.014, 0.070, 0.145),
        eta: 1.3,
        g: 0.0
    )
    static let skin2 = SubsurfaceMaterial(
        sigma_s_prime: SIMD3<Float>(1.09, 1.59, 1.79),
        sigma_a: SIMD3<Float>(0.013, 0.070, 0.15),
        eta: 1.3,
        g: 0.0
    )
    static let spectralon = SubsurfaceMaterial(
        sigma_s_prime: SIMD3<Float>(11.6, 20.4, 14.9),
        sigma_a: SIMD3<Float>(0.00, 0.00, 0.00),
        eta: 1.3,
        g: 0.0
    )
    static let wholeMilk = SubsurfaceMaterial(
        sigma_s_prime: SIMD3<Float>(2.55, 3.21, 3.77),
        sigma_a: SIMD3<Float>(0.0011, 0.0024, 0.014),
        eta: 1.3,
        g: 0.0
    )

    public static func == (lhs: SubsurfaceMaterial, rhs: SubsurfaceMaterial) -> Bool {
        var lhs = lhs, rhs = rhs
        return memcmp(&lhs, &rhs, MemoryLayout<Self>.size) == 0
    }
}
