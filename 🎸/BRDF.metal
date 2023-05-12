#import "BRDF.h"
#import "common.h"
#import "Sampler.h"
#import "SingleScattering.h"
#import "Diffusion.h"

Color getBRDF(const thread Hit &fromCamera, const thread Hit &toInfinity, thread SceneState &scene) {
    const thread Direction &inDir = fromCamera.inRay.direction;
    const thread Direction normal = normalize(fromCamera.normal);
    const constant Material &mat = fromCamera.tri.material;
    switch (fromCamera.tri.material.illum) {
        case Illum::diffuse: {
            if (!scene.settings.subsurfaceScatteringOn) {
                return float3(0.f,0.f,0.f);
            } else if (!scene.settings.singleSSOn || !scene.settings.diffusionSSOn) {
                ScatterMaterial mat {scene.settings, fromCamera.tri.material};

                //if only one or neither option is checked
                if (scene.settings.singleSSOn) {
                    return singleScatter(fromCamera, mat, scene);
                } else if (scene.settings.diffusionSSOn) {
                    return diffuseApproximation(fromCamera, toInfinity, mat, scene);
                } else {
                    return float3(0.f,0.f,0.f);
                }
            } else {
                //if both subsurface scattering options are checked, monte carlo the two types of scattering
                ScatterMaterial mat {scene.settings, fromCamera.tri.material};
                return singleScatter(fromCamera, mat, scene) + diffuseApproximation(fromCamera,toInfinity, mat, scene);
            }
        }
        case Illum::refract_fresnel:
        case Illum::glass:
            if (floatEpsEqual(refract(inDir, -normal, mat.ior), toInfinity.inRay.direction)
                || floatEpsEqual(refract(inDir, normal, 1/mat.ior), toInfinity.inRay.direction)
                || floatEpsEqual(reflect(inDir, normal), toInfinity.inRay.direction)) {
                return 1 / abs(dot(inDir, normal));
            }
            return Colors::black();
        case Illum::diffuse_specular_fresnel:
        case Illum::diffuse_specular:
            if (any(mat.specular > 0.01)) {
                if (mat.shininess > 100) {
                    if (floatEpsEqual(reflect(inDir, normal), toInfinity.inRay.direction)) {
                        return mat.specular / abs(dot(inDir, normal));
                    } else {
                        return Colors::black();
                    }
                } else {
                    // [Phong Glossy Specular BRDF];
                    float n = mat.shininess;
                    float3 s = mat.specular;
                    float3 normalized_color = ((n+2.f)/(2.f*M_PI_F))*s;
                    Direction norm = normalize(normal);
                    Direction reflectedVector = reflect(inDir, norm);
                    float dotProd = abs(dot(reflectedVector, normalize(toInfinity.inRay.direction)));
                    if (dotProd < 0) { return Colors::purple(); }
                    float reflectiveIntensity = pow(dotProd, n);

                    return normalized_color*reflectiveIntensity;
                }
            } else {
                // [diffuse BRDF];
                if (scene.settings.diffuseOn) {
                    return mat.diffuse/M_PI_F;
                } else {
                    return Colors::white();
                }
            }
            break;
        default:
            return 0.f; //TODO REMOVE
    }
}

Sample getNextDirection(const thread Hit &hit, thread SceneState &scene) {

    float e1 = scene.rng(); //random number
    float e2 = scene.rng(); //random number

    Sample result = {.hit = hit, .pdf = 1.f, .sampleDirectLighting = false,};
    switch (hit.tri.material.illum) {
        case Illum::diffuse: {
            if (!scene.settings.subsurfaceScatteringOn) {
                return generateRandomOnHemi(hit, float2(e1, e2));
            } else if (scene.settings.singleSSOn && !scene.settings.diffusionSSOn) {
                result.hit.inRay.direction = 0.f;
                return result;
//                return generateRandomOnHemi(hit, float2(e1, e2));
            } else {
                //if both subsurface scattering options are checked, monte carlo the two types of scattering
                return getNextDiffusionDirection(hit, scene);
            }
        }
        case Illum::refract_fresnel:
        case Illum::glass:
            // glass
            {
                float3 norm = hit.normal;
                float cos_theta_i = dot(norm, hit.inRay.direction);
                bool passingIntoGlass = cos_theta_i < 0;

                float ior = hit.tri.material.ior;//Diffuse color as array of floats
                float ior_i; //ior that the ray was passing through
                float ior_t; //ior that the ray is maybe going into

                //when the ray hits a boundary of a refractive object, it is not obvious whether the ray is entering the object or exiting.
                //Use normals to determine this (if ray is in the same direction as normal, it is leaving object)
                //We have guarantee that rays will only pass into refractive objects and then immediately air when passing out
                if (passingIntoGlass) {
                    cos_theta_i = abs(cos_theta_i);
                    ior_i = 1;
                    ior_t = ior;
                } else {
                    norm*=-1;
                    ior_i = ior;
                    ior_t = 1;
                }

                float sqdCos_t = 1.f-pow((ior_i/ior_t),2)*(1.f-pow(cos_theta_i,2));
                //if ior is already that of glass, change it back to air

                //for dielectric splitting (both reflection and refraction) use Schlick's approximation of how much light gets reflected
                float split = scene.rng();
                float r_0 = pow((ior_i-ior_t)/(ior_i+ior_t),2.f);
                float schlicks = r_0 + (1.f-r_0)*pow((1.f-cos_theta_i),5.f);


                if (split < schlicks || sqdCos_t < 0) { //if Schlicks, or if total internal reflection
                    //reflect
                    Direction incomingDir = normalize(hit.inRay.direction);
                    Direction reflectedVector = incomingDir - 2.f*dot(incomingDir,norm)*norm;
                    result.hit.inRay.direction = reflectedVector;
                    result.pdf = 1.f;
                    result.sampleDirectLighting = true;
                } else {
                    //refract
                    float cosTheta_t = sqrt(sqdCos_t);
                    float ratioIT = ior_i/ior_t;
                    //if the determinant is non-negative, we do not have total internal reflection
                    Direction refractedDir = ratioIT * hit.inRay.direction + (ratioIT * cos_theta_i - cosTheta_t)*norm;

                    //accumulate the radiance of the next path!
                    result.hit.inRay.direction = refractedDir;
                    result.pdf = 1.f;
                    result.sampleDirectLighting = true;

                }
                return result;
            }
            break;
        case Illum::diffuse_specular_fresnel:
        case Illum::diffuse_specular:
            if (any(hit.tri.material.specular>0.01)) {
                if (hit.tri.material.shininess > 100) {
                    // mirror
                    if (scene.settings.mirrorOn) {
                        Direction reflectedVector = hit.inRay.direction - 2.f*dot(hit.inRay.direction, hit.normal)*hit.normal;
                        result.hit.inRay.direction = reflectedVector;
                        result.pdf = 1.f;
                        result.sampleDirectLighting = true;
                        return result;
                    } else {
                        return generateRandomOnHemi(hit, float2(e1, e2));
                    }
                } else {
                    // specular BRDF;
                    if (scene.settings.importanceSamplingOn) {
                        //TODO
                        float shine = hit.tri.material.shininess;

                        float phi = 2.0 * M_PI_F * e1;
                        float theta = acos(pow(e2, 1/(1+shine)));

                        Direction objSpaceRand = float3(1.*sin(theta)*cos(phi), 1.*cos(theta), 1.*sin(theta)*sin(phi));

                        result.pdf = (shine+2.f)/(2.f*M_PI_F)*(pow(cos(theta),shine));

                        Direction reflectedVector = hit.inRay.direction - 2.f*(dot(hit.inRay.direction,hit.normal))*hit.normal;

                        result.hit.inRay.direction = alignHemisphereWithNormal(objSpaceRand, reflectedVector);

                        return result;
                    } else {
                        return generateRandomOnHemi(hit, float2(e1, e2));
                    }
                }
            } else {
                // diffuse [importance sampling does not work :(]
//                if (scene.settings.importanceSamplingOn) {
//                    float phi = 2.0 * M_PI_F * e1;
//                    float theta = asin(e2);
//                    Direction objSpaceRand = normalize(float3(1.*sin(theta)*cos(phi), 1.*cos(theta), 1.*sin(theta)*sin(phi)));
//                    result.hit.inRay.direction = normalize(alignHemisphereWithNormal(objSpaceRand, hit.normal));
//                    result.pdf = max(0.f, dot(hit.normal,result.hit.inRay.direction));
//                    return result;
//                } else {
                    return generateRandomOnHemi(hit, float2(e1, e2));
//                }
            }
            break;
        default:
            result.hit.inRay.direction = 0;
            result.pdf = 1;
            return result;
    }
}

Sample generateRandomOnHemi(const thread Hit &hit, float2 uv) {
    Sample result{.hit = hit, .pdf = 1.f/(2.f*M_PI_F)};
    float3 randomHemi = sampleCosineWeightedHemisphere(uv); //pick a random direction on the hemisphere
    result.hit.inRay.direction = alignHemisphereWithNormal(randomHemi, hit.normal); //align the random direction with the normal
    return result;
}
