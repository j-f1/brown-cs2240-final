
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

float fresnel(const thread float ior, const thread Direction normal, const thread ray inRay) {
    return 0.f;
}

Hit sampleSurface(const thread Hit &originalHit, const thread SceneState &scene) {
    return originalHit; //TODO fill out this method with the random hemisphere sampling
}

Color diffuseReflectance(const thread Hit &inHit, const thread Hit &outHit) {
    float albedo = 0.5; //marble TODO SHOULD THIS BE A CONSTANT??
   
    return float3(0.f,0.f,0.f);
}

Color diffuseApproximation(const thread Hit &outHit, const thread ScatterMaterial &mat, const thread SceneState &scene) {
    Hit inHit = sampleSurface(outHit, scene);
    Color R_d = diffuseReflectance(inHit, outHit);
    float fresnelIn = fresnel(mat.ior, inHit.normal, inHit.inRay);
    float fresnelOut = fresnel(mat.ior, outHit.normal, outHit.inRay);
    
    return (1.f/M_PI_F)*fresnelIn*R_d*fresnelOut;
}
