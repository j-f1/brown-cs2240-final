#import "common.h"
#import "Diffusion.h"
#import "Sampler.h"

/**
 HIT:
 tri tri;
 Location location;
 Direction normal;
 const thread ray &inRay;
 const thread Intersector::Intersection &intersection;
 */

Hit sampleSurface(const thread Hit &originalHit, const thread SceneState &scene) {
    //go down along the normal an average of the distance to each point (this is arbitrary but just to keep it at the scale of the tris)
    Location point = originalHit.location;
    float dist1 = length(point-originalHit.tri.v1);
    float dist2 = length(point-originalHit.tri.v2);
    float dist3 = length(point-originalHit.tri.v3);
    float avgDist = (dist1+dist2+dist3)/3.f;
    Location shootRayOrigin = point-originalHit.normal*avgDist;
    
    float2 uv (scene.rng(), scene.rng());
    float3 randomHemi = sampleCosineWeightedHemisphere(uv); //pick a random direction on the hemisphere
    Direction rayDirection = alignHemisphereWithNormal(randomHemi, originalHit.normal); //align the random direction with the normal
    
    ray nextDir = ray{shootRayOrigin, 0.f, 0.0, INFINITY};
    nextDir.direction = rayDirection;
    
    Intersector::Intersection intersection = scene.intersector(nextDir);
    
    //todo does this make everything go forever?
    while (!intersection) { //if it doesn't hit anything (perhaps we went too far down)
        float2 uv (scene.rng(), scene.rng());
        float3 randomHemi = sampleCosineWeightedHemisphere(uv); //pick a random direction on the hemisphere
        Direction rayDirection = alignHemisphereWithNormal(randomHemi, originalHit.normal); //align the random direction with the normal

        ray nextDir = ray{shootRayOrigin, 0.f, 0.0, INFINITY};
        nextDir.direction = rayDirection;

        intersection = scene.intersector(nextDir);
    }
    
    return Hit(intersection, scene);
}

Color diffuseReflectance(const thread Hit &inHit, const thread ScatterMaterial &mat, const thread Hit &outHit) {
    float3 albedo_prime = mat.σs_prime/mat.σt_prime; //from "Reflection from Layered Surfaces due to Subsurface Scattering"
    float3 σ_tr = sqrt(3.f*mat.σa*(mat.σt_prime));
    float F_dr = (-1.440/(mat.ior*mat.ior))+(0.710/mat.ior)+0.668+(0.0636*mat.ior);
    float3 z_r = 1.f/mat.σt_prime; //also d_r //TODO SHOULD THIS BE A FLOAT3 OR JUST A FLOAT?? IF IT'S A DISTANCE??
    float A = (1+F_dr)/(1-F_dr);
    float3 D = (1.f/(3.f*mat.σt_prime));
    float3 z_v = z_r + 4.f*A*D; //also d_v, right??
    
    Location virtualLight = normalize(inHit.normal)*z_v + inHit.location; //put the virtual light z_v above the surface
    Location realLight = -normalize(inHit.normal)*z_r + inHit.location; //put the real light z_r under the surface
    
    float d_v = length(outHit.location-virtualLight);
    float d_r = length(outHit.location-realLight);
    
    float3 leftTerm = (σ_tr*d_r+1.f)*(exp(-σ_tr*d_r)/(mat.σt_prime*pow(d_r,3)));
    float3 rightTerm = z_v*(σ_tr*d_v+1.f)*(exp(-σ_tr*d_v)/(mat.σt_prime*pow(d_v,3)));
    float3 reflectance = (albedo_prime/(4.f*M_PI_F))*(leftTerm + rightTerm);
    
    return reflectance;
}

float3 calculateDensity (const thread Hit &inHit, const thread ScatterMaterial &mat, const thread Hit &outHit) {
    float3 σ_tr = sqrt(3.f*mat.σa*(mat.σt_prime));
    float dist = length(inHit.location-outHit.location);
    float3 density = σ_tr*exp(-σ_tr*dist); //euclidian distance might not be ideal for this but ¯\_(ツ)_/¯
    return density;
}

Color diffuseApproximation(const thread Hit &outHit, const thread ScatterMaterial &mat, const thread SceneState &scene) {
    Hit inHit = sampleSurface(outHit, scene);
    Color R_d = diffuseReflectance(inHit, mat, outHit);
    float fresnelIn = fresnel(mat.ior, -inHit.normal, inHit.inRay);
    float fresnelOut = fresnel(mat.ior, outHit.normal, outHit.inRay);
//    fresnelIn = 0.5;
    
    float3 pdf = calculateDensity(inHit, mat, outHit); //TODO
    
    return (1.f/M_PI_F)*fresnelIn*R_d*fresnelOut/pdf;
    
}
