#import "common.h"
#import "DirectLighting.h"

Color directLighting(const thread Hit &hit, thread SceneState &scene) {
    Color result = Colors::black();
    for (tri t : scene.emissives) {
        for (int j = 0; j < scene.settings.directLightingSamples; j++) {
            const Location target = t.sample(scene.rng);
            float3 dir = normalize(target - hit.location);
            if (dot(dir, hit.normal) < 0) continue;
            ray outRay = hit.inRay;
            outRay.origin = hit.location;
            outRay.direction = dir;
            auto intersection = scene.intersector(outRay);
            if (!intersection) continue;
            if (intersection.index() != t.idx) continue; // skip if there’s an obstacle
            if (dot(t.faceNormal, -dir) < 0) continue;
            float area = length(cross((t.v2 - t.v1), (t.v3 - t.v1))) / 2;
            float distanceFactor = dot(hit.normal, dir) * abs(dot(t.faceNormal, -dir)) / length_squared(target - outRay.origin);
            float3 brdf = 1.f; // TODO: brdf(-dir, outRay.direction, normal, material);
            float3 contribution = brdf * t.material.emission * area * distanceFactor;
            result += contribution;
        }
    }
    return result / float(scene.settings.directLightingSamples);
}
