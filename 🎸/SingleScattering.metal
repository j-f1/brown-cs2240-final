#import "SingleScattering.h"

float estimateRefractedInefficiency(const thread ScatterMaterial &mat, Direction dir, Direction normal) {
    float factor = abs(dot(dir, normal));
    return factor / sqrt(1 - mat.mat.ior * mat.mat.ior * (1 - factor * factor));
}

Color singleScatter(const thread Hit &hit, const thread ScatterMaterial &mat, const thread SceneState &scene) {
    float sPrimeOut = log(1.f - scene.rng()) / mat.σt;
    Location scatterPos = hit.inRay.origin + hit.inRay.direction * sPrimeOut;
    // TODO: skip if pos is outside of object?
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

    float sPrimeIn = surface.distance() * estimateRefractedInefficiency(mat, lightDir, hit.normal);
    return surface.material(scene).emission;
}
