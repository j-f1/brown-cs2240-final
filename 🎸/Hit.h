#include "common.h"

struct Hit {
    Hit(const thread Intersector::Intersection &intersection, const thread SceneState &scene, const thread ray &inRay);

    tri tri;
    Location location;
    Direction normal;
    const thread ray &inRay;
};

