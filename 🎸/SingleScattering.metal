#import "SingleScattering.h"
#import "Sampler.h"

float estimateRefractedInefficiency(const thread ScatterMaterial &mat, Direction dir, Direction normal) {
    float factor = abs(dot(dir, normal));
    float eta = 1/mat.ior;
    return factor / sqrt(1 - eta * eta * (1 - factor * factor));
}

struct Scatter {
    bool ok;
    Intersector::Intersection surface;
    float distance;
    Location lightPos;
    Direction lightDir;
    float sPrimeOut;
};

Scatter sampleSurface(const thread Hit &hit, float scale, const thread tri &light, const thread ScatterMaterial &mat, const thread SceneState &scene) {
    // correct if material is isotropic
    float σt = (mat.σt_prime.x + mat.σt_prime.y + mat.σt_prime.z) / 3;

    float sPrimeOut = -log(1.f - scene.rng() * scale) / σt;
    
    // TODO: skip if pos is outside of object?
    Location scatterPos = hit.location + hit.inRay.direction * sPrimeOut;
    Location sample = light.sample(scene.rng);
    Direction lightDir = normalize(sample - scatterPos);

    ray surfaceTest = hit.inRay;
    surfaceTest.origin = scatterPos;
    surfaceTest.direction = lightDir;
    surfaceTest.min_distance = 0;
    auto surface = scene.intersector(surfaceTest);
    if (!surface) {
        // ???
        return { .ok = false, .surface = surface };
    }
    Hit surfaceHit{surface, scene};

    if (surface.index() == light.idx || scene.materialIds[surface.index()] != hit.tri.materialIdx) {
        return { .ok = false, .surface = surface };
    }

    if (dot(surfaceHit.normal, lightDir) < 0) {
        // ??????
        return { .ok = false, .surface = surface };
    }

    return {
        .ok = true,
        .surface = surface,
        .distance = surface.distance(),
        .lightPos = sample,
        .lightDir = lightDir,
        .sPrimeOut = sPrimeOut
    };
}

// magic numbers, tweak to adjust failure rate
#define DEPTH_DOWNSCALE_FACTOR   8
#define DEPTH_RESAMPLE_MAX_STEPS 3

Color singleScatter(const thread Hit &hit, const thread ScatterMaterial &mat, const thread SceneState &scene) {
    tri light = scene.emissives.random();

    Scatter scatter { .ok = false, .surface = hit.intersection };
    int i = 0;
    float scale = 1;
    while (!scatter.ok) {
        if (i++ > DEPTH_RESAMPLE_MAX_STEPS) return Colors::black();
        scatter = sampleSurface(hit, scale, light, mat, scene);
        scale /= DEPTH_DOWNSCALE_FACTOR;
    }
    Hit surfaceHit{scatter.surface, scene};

    // correct if material is isotropic
    float σt = (mat.σt_prime.x + mat.σt_prime.y + mat.σt_prime.z) / 3;
    float3 σs = mat.σs_prime;

    float sPrimeIn = scatter.distance * estimateRefractedInefficiency(mat, scatter.lightDir, hit.normal);
    float σtc = σt * (1 + abs(dot(surfaceHit.normal, hit.inRay.direction)) / abs(dot(hit.normal, surfaceHit.inRay.direction)));
    float fresnelValue = fresnel(mat.mat.ior, surfaceHit.normal, surfaceHit.inRay.direction) * fresnel(mat.mat.ior, hit.normal, -hit.inRay.direction);
    float phase = mat.phase(surfaceHit.inRay.direction, hit.inRay.direction);
    float attenuation = exp(-σt * (sPrimeIn + scatter.sPrimeOut));
    float area = length(cross((hit.tri.v2 - hit.tri.v1), (hit.tri.v3 - hit.tri.v1))) / 2;
    float distanceFactor = dot(surfaceHit.normal, scatter.lightDir) * abs(dot(light.faceNormal, -scatter.lightDir)) / length_squared(scatter.lightPos - surfaceHit.location);
    float3 color = area * distanceFactor * attenuation * light.material.emission;
    return σs / σtc * fresnelValue * phase * attenuation * color;
}
