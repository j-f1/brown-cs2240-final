#import "common.h"
#import "Hit.h"

struct Sample {
    Hit hit;
    float pdf;
    bool reflection;
};

Color getBRDF(const thread Hit &hit, const thread Hit &outHit, thread SceneState &scene);

Sample getNextDirection(const thread Hit &hit, thread SceneState &scene);

Sample generateRandomOnHemi(const thread Hit &hit, float2 uv);
