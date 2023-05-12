#import "common.h"
#import "Tri.h"

struct Hit {
    Hit(const thread Intersector::Intersection &intersection, const thread SceneState &scene);

    tri tri;
    Location location;
    Direction normal;
    ray inRay;
    const thread Intersector::Intersection &intersection;
};

