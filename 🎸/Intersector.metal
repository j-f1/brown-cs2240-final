#import "Intersector.h"
#import "Tri.h"

const constant Material &Intersector::Intersection::material(const thread SceneState &scene) const {
    return scene.materials[scene.materialIds[index()]];
}

const tri Intersector::Intersection::tri(const thread SceneState &scene) const {
    return {index(), scene};
}
