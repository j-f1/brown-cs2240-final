#import "common.h"
#import "Hit.h"
#import "Sample.h"

Color diffuseApproximation(const thread Hit &fromCamera, const thread Hit &toInfinity, const thread ScatterMaterial &mat, const thread SceneState &scene);

Sample getNextDiffusionDirection(const thread Hit &hit, thread SceneState &scene);
