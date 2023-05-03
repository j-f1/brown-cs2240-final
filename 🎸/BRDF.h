#import "common.h"
#import "Hit.h"

Color getBRDF(const thread Hit &hit, const thread Direction &outDir, thread SceneState &scene);

Sample getNextDirection(const thread Hit &hit, thread SceneState &scene);

Sample generateRandomOnHemi(Direction normal, float2 uv);
