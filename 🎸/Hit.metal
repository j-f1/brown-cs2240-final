#import "Hit.h"

//generate the smooth normal??
Direction generateWeightedNormal(const thread tri &hit, Location location, const thread SceneState &scene) {
    if (floatEpsEqual(length_squared(hit.n1), 0) || floatEpsEqual(length_squared(hit.n2), 0) || floatEpsEqual(length_squared(hit.n3), 0)) {
        return normalize(hit.faceNormal);
    }

    Location v0 = hit.v2 - hit.v1;
    Location v1 = hit.v3 - hit.v1;
    Location v2 = location - hit.v1;
    float d00 = dot(v0,v0);
    float d01 = dot(v0,v1);
    float d11 = dot(v1,v1);
    float d20 = dot(v2,v0);
    float d21 = dot(v2,v1);
    float denom = d00 * d11 - d01 * d01;
    float v = (d11 * d20 - d01 * d21) / denom;
    float w = (d00 * d21 - d01 * d20) / denom;
    float u = 1.f - v - w;

    Direction interpolated_normal = normalize(u * hit.n1 + v * hit.n2 + w * hit.n3);
    return interpolated_normal;
}


Hit::Hit(const thread Intersector::Intersection &intersection, const thread SceneState &scene, const thread ray &inRay)
: tri(intersection.tri(scene))
, location(intersection.location())
, normal(generateWeightedNormal(tri, location, scene))
, inRay(inRay)
{}

