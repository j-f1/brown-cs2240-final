#import "common.h"

struct tri {
    inline tri(int idx, const thread SceneState &scene) : idx(idx) {
        ushort3 vertIndices = unpack(scene.vertices, idx);
        v1 = unpack<Location>(scene.positions, vertIndices.x);
        v2 = unpack<Location>(scene.positions, vertIndices.y);
        v3 = unpack<Location>(scene.positions, vertIndices.z);
        normal = unpack<Direction>(scene.normals, idx);
        auto materialId = scene.materialIds[idx];
        material = scene.materials[materialId];
    }

    int idx;
    Material material;
    Direction normal;
    Location v1, v2, v3;

    inline Location sample(thread RandomGenerator &rng) const {
        // https://math.stackexchange.com/a/538472/415698
        return v1 + rng() * (v2 - v1) + rng() * (v3 - v1);
    }
};

Color directLighting(const thread ray &inRay, Location location, Direction normal, const thread Material &material, thread SceneState &scene) {
    Color result = Colors::black();
    for (int i = 0; i < scene.emissivesCount; i++) {
        tri t{scene.emissives[i], scene};

        for (int j = 0; j < scene.settings.directLightingSamples; j++) {
            const Location target = t.sample(scene.rng);
            float3 dir = normalize(target - location);
            if (dot(dir, normal) < 0) continue;
            ray outRay = inRay;
            outRay.origin = location;
            outRay.direction = dir;
            auto hit = scene.intersector(outRay);
            if (!hit) continue;
            if (hit.index() != t.idx) continue; // skip if there’s an obstacle
            if (dot(t.normal, -dir) < 0) continue;
            float area = length(cross((t.v2 - t.v1), (t.v3 - t.v1))) / 2;
            float distanceFactor = dot(normal, dir) * abs(dot(t.normal, -dir)) / length_squared(target - outRay.origin);
            float3 brdf = 1.f; // TODO: brdf(-dir, outRay.direction, normal, material);
            float3 contribution = brdf * t.material.emission * area * distanceFactor;
            result += contribution;
        }
    }
    return result / float(scene.settings.directLightingSamples);
}
