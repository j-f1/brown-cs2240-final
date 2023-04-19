#import "common.h"

Location sampleTriangle() {
    // ???
    return {0, 0, 0};
}

template<typename T>
const Color directLighting(const thread ray &outRay, const thread Direction &normal, const thread typename T::material &material, int samples, const thread SceneState &scene) {
    Color result = Color::black();
    for (int i = 0; i < scene.emissivesCount; i++) {
        Intersection intersection;
        // ???
        // const Triangle t{}; // ??? scene.triangles[scene.emissives[i]];
        for (int j = 0; j < samples; j++) {
            const Location target = sampleTriangle(); // ???
            Direction dir = Direction(outRay.origin, target);
            if (dir.dot(normal) < 0) continue;
//            if (!scene)
//            if (!scene.getIntersection({outRay.origin, dir}, &intersection)) continue;
//            const Triangle *hit = static_cast<const Triangle *>(intersection.data);
//            if (hit->getIndex() != tri->getIndex()) continue;
//            const struct tri t = tri;
//            const auto &lightNormal = Direction::_wrap(tri->getNormal(i));
//            if (lightNormal.dot(-dir) < 0) continue;
//            float area = (t.v2 - t.v1).cross(t.v3 - t.v1).norm() / 2;
//            float distanceFactor = normal.dot(dir) * abs(lightNormal.dot(-dir))  / (target - outRay.origin()).squaredNorm();
//            Color brdf = T::brdf(-dir, outRay.direction(), normal, material);
//            result += Color(tri->getMaterial().emission).componentWiseProduct(brdf) * area * distanceFactor;
        }
    }
    return result / samples;
}
