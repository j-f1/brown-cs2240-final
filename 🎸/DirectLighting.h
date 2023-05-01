#import "common.h"

Color directLighting(const thread ray &outRay, Location location, Direction normal, const thread Material &material, thread SceneState &scene);

struct tri {
    inline tri(int idx, const thread SceneState &scene) : idx(idx) {
        ushort3 vertIndices = unpack(scene.vertices, idx);
        v1 = unpack<Location>(scene.positions, vertIndices.x);
        v2 = unpack<Location>(scene.positions, vertIndices.y);
        v3 = unpack<Location>(scene.positions, vertIndices.z);
        ushort3 normalIndices = unpack(scene.faceVertexNormals, idx);
        n1 = unpack<Direction>(scene.vertexNormalDirections, normalIndices.x);
        n2 = unpack<Direction>(scene.vertexNormalDirections, normalIndices.y);
        n3 = unpack<Direction>(scene.vertexNormalDirections, normalIndices.z);
        faceNormal = unpack<Direction>(scene.normals, idx);
        auto materialId = scene.materialIds[idx];
        material = scene.materials[materialId];
    }

    int idx;
    Material material;
    Direction faceNormal;
    Location v1, v2, v3;
    Direction n1, n2, n3;

    inline Location sample(thread RandomGenerator &rng) const {
        // https://math.stackexchange.com/a/538472/415698
        return v1 + rng() * (v2 - v1) + rng() * (v3 - v1);
    }
};
