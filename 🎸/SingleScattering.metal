#import "SingleScattering.h"
#import "Sampler.h"

float estimateRefractedInefficiency(const thread ScatterMaterial &mat, Direction dir, Direction normal) {
    float factor = abs(dot(dir, normal));
    float eta = 1/mat.ior;
    return factor / sqrt(1 - eta * eta * (1 - factor * factor));
}

Color singleScatter(const thread Hit &hit, const thread ScatterMaterial &mat, const thread SceneState &scene) {
    float sPrimeOut = -log(1.f - scene.rng()) / mat.σt;
    // TODO: skip if pos is outside of object?
    Location scatterPos = hit.inRay.origin + hit.inRay.direction * sPrimeOut;
    tri light = scene.emissives.random();

    Location sample = light.sample(scene.rng);
    Direction lightDir = normalize(sample - scatterPos);

    ray surfaceTest = hit.inRay;
    surfaceTest.origin = scatterPos;
    surfaceTest.direction = lightDir;
    auto surface = scene.intersector(surfaceTest);
    if (!surface) {
        // ???
        return Colors::pink();
    }
    Hit surfaceHit{surface, scene};

    float sPrimeIn = surface.distance() * estimateRefractedInefficiency(mat, lightDir, hit.normal);
    float σtc = mat.σt * (1 + abs(dot(surfaceHit.normal, hit.inRay.direction)) / abs(dot(hit.normal, surfaceHit.inRay.direction)));
    // TODO(jed): fresnel
    float fresnel = 50; // fresnelTransmittance(mat.mat.ior, surfaceHit.inRay.direction) * fresnelTransmittance(mat.mat.ior, hit.inRay.direction);
    float phase = mat.phase(surfaceHit.inRay.direction, hit.inRay.direction);
    float attenuation = exp(-mat.σt * (sPrimeIn + sPrimeOut));
    float area = length(cross((hit.tri.v2 - hit.tri.v1), (hit.tri.v3 - hit.tri.v1))) / 2;
    float distanceFactor = dot(surfaceHit.normal, lightDir) * abs(dot(light.faceNormal, -lightDir)) / length_squared(sample - surfaceHit.location);
    float3 color = area * distanceFactor * surface.material(scene).emission;
    return mat.σs / σtc * fresnel * phase * 1 * color;
}
