#import "common.h"
#import "Hit.h"
#import "Sample.h"

Color getBRDF(const thread Hit &hit, const thread Hit &outHit, thread SceneState &scene);

Sample getNextDirection(const thread Hit &hit, thread SceneState &scene);

Sample generateRandomOnHemi(const thread Hit &hit, float2 uv);
