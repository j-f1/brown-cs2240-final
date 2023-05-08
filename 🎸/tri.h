#import "common.h"

struct tri {
    int idx;
    int materialIdx;
    const constant Material &material;
    Direction faceNormal;
    Location v1, v2, v3;
    Direction n1, n2, n3;

    inline Location sample(thread RandomGenerator &rng) const {
        // https://math.stackexchange.com/a/538472/415698
        return v1 + rng() * (v2 - v1) + rng() * (v3 - v1);
    }

    friend struct Intersector::Intersection;
    friend struct EmissiveList::Iterator;
protected:
    inline tri(int idx, const thread SceneState &scene)
    : idx(idx), material(scene.materials[scene.materialIds[idx]]) {
        materialIdx = scene.materialIds[idx];
        ushort3 vertIndices = unpack(scene.vertices, idx);
        v1 = unpack(scene.positions, vertIndices.x);
        v2 = unpack(scene.positions, vertIndices.y);
        v3 = unpack(scene.positions, vertIndices.z);
        ushort3 normalIndices = unpack(scene.faceVertexNormals, idx);
        n1 = unpack(scene.vertexNormalDirections, normalIndices.x);
        n2 = unpack(scene.vertexNormalDirections, normalIndices.y);
        n3 = unpack(scene.vertexNormalDirections, normalIndices.z);
        faceNormal = unpack(scene.normals, idx);
    }
};
