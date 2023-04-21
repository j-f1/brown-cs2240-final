#import "common.h"

struct tri {
    inline tri(int idx, const thread SceneState &scene) : idx(idx), material(scene.materials[scene.materialIds[idx]]) {
        ushort3 vertIndices = unpack(scene.vertices, idx);
        v1 = unpack<Location>(scene.positions, vertIndices.x);
        v2 = unpack<Location>(scene.positions, vertIndices.y);
        v3 = unpack<Location>(scene.positions, vertIndices.z);
        normal = unpack<Direction>(scene.normals, idx);
    }

    int idx;
    const constant Material &material;
    Direction normal;
    Location v1, v2, v3;

    inline Location sample(thread RandomGenerator &rng) const {
        // https://math.stackexchange.com/a/538472/415698
        return Location::_wrap(v1._unwrap() + rng() * (v2._unwrap() - v1._unwrap()) + rng() * (v3._unwrap() - v1._unwrap()));
    }
};

Color directLighting(const thread ray &inRay, Direction normal, const thread Material &material, thread SceneState &scene) {
    Color result = Color::black();
    for (int i = 0; i < scene.emissivesCount; i++) {
        tri t{scene.emissives[i], scene};

        for (int j = 0; j < scene.settings.directLightingSamples; j++) {
            const Location target = t.sample(scene.rng);
            Direction dir = Direction(inRay.origin, target);
            if (dir.dot(normal) < 0) continue;
            ray outRay = inRay;
            outRay.direction = dir._unwrap();
            auto hit = scene.intersector(outRay);
            if (!hit) continue;
            if (hit.index() != t.idx) continue; // skip if there’s an obstacle
            if (t.normal.dot(-dir) < 0) continue;
            float area = length(cross((t.v2 - t.v1), (t.v3 - t.v1))) / 2;
            float distanceFactor = normal.dot(dir) * abs(t.normal.dot(-dir)) / length_squared(target._unwrap() - outRay.origin);
            Color brdf = Color::white(); // TODO: brdf(-dir, outRay.direction, normal, material);
            result += brdf.componentWiseProduct(Color{t.material.emission}) * area * distanceFactor;
        }
    }
    return result / float(scene.settings.directLightingSamples);
}
