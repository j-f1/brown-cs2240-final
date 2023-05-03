#import "SingleScattering.h"

float estimateRefractedDistance(const thread ScatterMaterial &mat, Direction dir, Direction normal) {
    float factor = abs(dot(dir, normal));
    return factor / sqrt(1 - mat.mat.ior * mat.mat.ior * (1 - factor * factor));
}

ScatterResult singleScatter(const thread Hit &hit, const thread ScatterMaterial &mat, const thread SceneState &state) {
    float sPrimeOut = log(1.f - state.rng()) / mat.σt;
    Location scatterPos = hit.inRay.origin + hit.inRay.direction * sPrimeOut;
    // TODO: skip if pos is outside of object?
    tri light{state.emissives[int(state.rng() * state.emissivesCount)], state};

    Location sample = light.sample(state.rng);
    Direction lightDir = normalize(sample - hit.location);
    //WIP!

    float sPrimeIn = estimateRefractedDistance(mat, lightDir, hit.normal);

    return {};
}
