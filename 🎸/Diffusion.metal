#import "common.h"
#import "Diffusion.h"
#import "Sampler.h"

inline Intersector::Intersection densityBasedSample(const thread Hit &originalHit, const thread ScatterMaterial &mat, const thread SceneState &scene) {
    float avgDist = 0.0001;
    Location shootRayOrigin = originalHit.location - originalHit.normal*avgDist;

    float E1 = scene.rng();
    float E2 = scene.rng();
    float3 σ_tr = sqrt(3.f*mat.σa*(mat.σt_prime));
    float σ_tr_avg = (σ_tr.x+σ_tr.y+σ_tr.z)/3.f;
    float θ = atan(-log(E1)/(avgDist*σ_tr_avg));
    float φ = E2*2*M_PI_F;

    Direction densityHemi = float3(sin(θ)*cos(φ),cos(θ),sin(θ)*sin(φ));
    Direction rayDirection = alignHemisphereWithNormal(densityHemi, originalHit.normal); //align the random direction with the normal

    ray nextDir = ray{shootRayOrigin, 0.f, 0.0, INFINITY};
    nextDir.direction = rayDirection;
    return scene.intersector(nextDir);
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

Color diffuseApproximation(const thread Hit &fromCamera, const thread Hit &toInfinity, const thread ScatterMaterial &mat, const thread SceneState &scene) {

    Color R_d = diffuseReflectance(fromCamera, mat, toInfinity);
    float fresnelIn = fresnel(mat.ior, fromCamera.normal, fromCamera.inRay.direction);
    float fresnelOut = fresnel(mat.ior, toInfinity.normal, toInfinity.inRay.direction);

//    fresnelIn = 1;
//    fresnelOut = 1;
    if (fresnelIn > 1 || fresnelOut > 1) return {1, 0, 0};

    return M_1_PI_F * fresnelIn * R_d * fresnelOut;
}


Sample getNextDiffusionDirection(const thread Hit &outHit, thread SceneState &scene) {
    ScatterMaterial mat {scene.settings, outHit.tri.material};
    int tries = 0;
    auto intersection = densityBasedSample(outHit, mat, scene);
    while ((!intersection || scene.materialIds[intersection.index()] != outHit.tri.materialIdx) && tries < 5) {
        intersection = densityBasedSample(outHit, mat, scene);
        tries++;
    }
    Hit inHit{intersection, scene};
    return Sample{.hit = inHit, .pdf = 1, .sampleDirectLighting = false};
}
