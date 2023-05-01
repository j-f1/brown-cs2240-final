#import "common.h"

Color getBRDF(const thread ray &inRay, const thread Direction normal, const thread Direction &outDir, const thread Material &mat, thread SceneState &scene);

Sample getNextDirection(const thread Location &intersectionPoint, const thread Direction normal, const thread Material &mat, const thread ray &inRay, thread SceneState &scene);

Direction generateWeightedNormal(thread Intersector::Intersection intersection, thread SceneState& scene);

Sample generateRandomOnHemi(Direction normal, float2 uv);
