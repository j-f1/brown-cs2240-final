#import "common.h"
#import "tri.h"

struct Hit {
    Hit(const thread Intersector::Intersection &intersection, const thread SceneState &scene);

    tri tri;
    Location location;
    Direction normal;
    const thread ray &inRay;
};

