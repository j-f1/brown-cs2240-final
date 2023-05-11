#import "common.h"
#import "Diffusion.h"
#import "Sampler.h"

Hit densityBasedSample (const thread Hit &originalHit, const thread ScatterMaterial &mat, const thread SceneState &scene) {
    Location point = originalHit.location;
    
    float E1 = scene.rng();
    float E2 = scene.rng();
    
    float avgDist = 0.0001;
    Location shootRayOrigin = point-originalHit.normal*avgDist;
    
    
    float3 σ_tr = sqrt(3.f*mat.σa*(mat.σt_prime));
    float σ_tr_avg = (σ_tr.x+σ_tr.y+σ_tr.z)/3.f;
    float θ = atan(-log(E1)/(avgDist*σ_tr_avg));
    float φ = E2*2*M_PI_F;
    Direction densityHemi = float3(sin(θ)*cos(φ),cos(θ),sin(θ)*sin(φ));
    
    Direction rayDirection = alignHemisphereWithNormal(densityHemi, originalHit.normal); //align the random direction with the normal
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
    float σt_prime_avg = (mat.σt_prime.x+mat.σt_prime.y+mat.σt_prime.z)/3.f;
    float3 albedo_prime = mat.σs_prime/mat.σt_prime; //from "Reflection from Layered Surfaces due to Subsurface Scattering"
    float3 σ_tr = sqrt(3.f*mat.σa*(mat.σt_prime));
    float F_dr = (-1.440/(mat.ior*mat.ior))+(0.710/mat.ior)+0.668+(0.0636*mat.ior);
    float z_r = 1.f/σt_prime_avg;
    float3 z_r3 = 1.f/mat.σt_prime;
    float A = (1+F_dr)/(1-F_dr);
    float D = (1.f/(3.f*σt_prime_avg));
    float z_v = z_r + 4.f*A*D;
    float3 z_v3 = z_r3 + 4.f*A*D;

    Location virtualLight = normalize(inHit.normal)*z_v + inHit.location; //put the virtual light z_v above the surface
    Location realLight = -normalize(inHit.normal)*z_r + inHit.location; //put the real light z_r under the surface
    
    float d_v = length(outHit.location-virtualLight);
    float d_r = length(outHit.location-realLight);
    
    float3 leftTerm = (σ_tr*d_r+1.f)*(exp(-σ_tr*d_r)/(mat.σt_prime*pow(d_r,3)));
    float3 rightTerm = z_v3*(σ_tr*d_v+1.f)*(exp(-σ_tr*d_v)/(mat.σt_prime*pow(d_v,3)));
    float3 reflectance = (albedo_prime/(4.f*M_PI_F))*(leftTerm + rightTerm);
    
    return reflectance;
}

Color diffuseApproximation(const thread Hit &outHit, const thread ScatterMaterial &mat, const thread SceneState &scene) {
    Hit inHit = densityBasedSample(outHit, mat, scene);
    Color R_d = diffuseReflectance(inHit, mat, outHit);
    float fresnelIn = fresnel(mat.ior, inHit.normal, inHit.inRay);
    float fresnelOut = fresnel(mat.ior, -outHit.normal, outHit.inRay);

    return clamp((1.f/M_PI_F)*fresnelIn*R_d*fresnelOut, 0.f, 1.f);//
    
}
