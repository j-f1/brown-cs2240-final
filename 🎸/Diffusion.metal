
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

Color diffuseReflectance(const thread Hit &inHit, const thread ScatterMaterial &mat, const thread Hit &outHit) {
    float3 albedo_prime = mat.σs_prime/mat.σt_prime; //from "Reflection from Layered Surfaces due to Subsurface Scattering"
    float3 σ_tr = sqrt(3.f*mat.σa*(mat.σt_prime));
    float F_dr = (-1.440/(mat.ior*mat.ior))+(0.710/mat.ior)+0.668+(0.0636*mat.ior);
    float3 z_r = 1.f/mat.σt_prime; //also d_r //TODO SHOULD THIS BE A FLOAT3 OR JUST A FLOAT?? IF IT'S A DISTANCE??
    float A = (1+F_dr)/(1-F_dr);
    float3 D = (1.f/(3.f*mat.σt_prime));
    float3 z_v = z_r + 4.f*A*D; //also d_v, right??
    
    float3 leftTerm = (σ_tr*z_r+1.f)*(exp(-σ_tr*z_r)/(mat.σt_prime*pow(z_r,3)));
    float3 rightTerm = z_v*(σ_tr*z_v+1.f)*(exp(-σ_tr*z_v)/(mat.σt_prime*pow(z_v,3)));
    float3 reflectance = (albedo_prime/(4.f*M_PI_F))*(leftTerm + rightTerm);
    
    return float3(0.f,0.f,0.f);
}

Color diffuseApproximation(const thread Hit &outHit, const thread ScatterMaterial &mat, const thread SceneState &scene) {
    Hit inHit = sampleSurface(outHit, scene);
    Color R_d = diffuseReflectance(inHit, mat, outHit);
    float fresnelIn = fresnel(mat.ior, inHit.normal, inHit.inRay);
    float fresnelOut = fresnel(mat.ior, outHit.normal, outHit.inRay);
    
    float pdf = 1.f; //TODO
    
    return (1.f/M_PI_F)*fresnelIn*R_d*fresnelOut/pdf;
}
