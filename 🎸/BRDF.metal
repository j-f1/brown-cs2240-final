#import "BRDF.h"
#import "common.h"
#import "Sampler.h"
#import "SingleScattering.h"
#import "Diffusion.h"

//TODO eventually turn the outDir type to Ray because we will be in BSSDF land
Color getBRDF(const thread Hit &hit, const thread Direction &outDir, thread SceneState &scene) {
    const thread Direction &inDir = hit.inRay.direction;
    const thread Direction normal = normalize(hit.normal);
    const constant Material &mat = hit.tri.material;
    switch (hit.tri.material.illum) {
        case Illum::diffuse: {
            if (!scene.settings.singleSSOn || !scene.settings.diffusionSSOn) {
                ScatterMaterial mat {scene.settings, hit.tri.material};
                
                //if only one or neither option is checked
                if (scene.settings.singleSSOn) {
                    return singleScatter(hit, mat, scene);
                } else if (scene.settings.diffusionSSOn) {
                    return diffuseApproximation(hit, mat, scene);
                } else {
                    return float3(0.f,0.f,0.f);
                }
            } else {
                ScatterMaterial mat {scene.settings, hit.tri.material};
                float random = scene.rng();
                if (random>0.5) {
                    return singleScatter(hit, mat, scene)/0.5f;
                } else {
                    return diffuseApproximation(hit, mat, scene)/0.5f;
                }
            }
        }
        case Illum::refract_fresnel:
        case Illum::glass:
            if (floatEpsEqual(refract(inDir, -normal, mat.ior), outDir)
                || floatEpsEqual(refract(inDir, normal, 1/mat.ior), outDir)
                || floatEpsEqual(-reflect(inDir, normal), outDir)) {
                return 1 / abs(dot(inDir, normal));
            }
            return Colors::black();
        case Illum::diffuse_specular_fresnel:
        case Illum::diffuse_specular:
            if (any(mat.specular > 0)) {
                if (mat.shininess > 100) {
                    if (floatEpsEqual(reflect(inDir, normal), outDir)) {
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
                    Direction reflectedVector = normalize(inDir) - 2.f*dot(normalize(inDir), norm)*norm;
                    float dotProd = dot(reflectedVector, normalize(outDir));
                    if (dotProd < 0) {return float3(0.f, 0.f, 0.f);}
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
    
    //TODO COCO
    Sample result = {.direction = Direction(0,0,0), .location = hit.location, .pdf = 1.f, .reflection = false,};
    switch (hit.tri.material.illum) {
        case Illum::diffuse:
            // subsurface scattering
            // TODO: something here?
            result.direction = Direction(0, 0, 0);
            result.pdf = 1;
            return result;
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
                    result.direction = reflectedVector;
                    result.pdf = 1.f;
                    result.reflection = true;
                } else {
                    //refract
                    float cosTheta_t = sqrt(sqdCos_t);
                    float ratioIT = ior_i/ior_t;
                    //if the determinant is non-negative, we do not have total internal reflection
                    Direction refractedDir = ratioIT * hit.inRay.direction + (ratioIT * cos_theta_i - cosTheta_t)*norm;
                    
                    //accumulate the radiance of the next path!
                    result.direction = refractedDir;
                    result.pdf = 1.f;
                    result.reflection = true;
                    
                }
                return result;
            }
            break;
        case Illum::diffuse_specular_fresnel:
        case Illum::diffuse_specular:
            if (any(hit.tri.material.specular>0)) {
                if (hit.tri.material.shininess > 100) {
                    // mirror
                    if (scene.settings.mirrorOn) {
                        Direction reflectedVector = hit.inRay.direction - 2.f*dot(hit.inRay.direction, hit.normal)*hit.normal;
                        result.direction = reflectedVector;
                        result.pdf = 1.f;
                        result.reflection = true;
                        return result;
                    } else {
                        return generateRandomOnHemi(hit.normal, float2(e1, e2));
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

                        result.direction = alignHemisphereWithNormal(objSpaceRand, reflectedVector);

                        return result;
                    } else {
                        return generateRandomOnHemi(hit.normal, float2(e1, e2));
                    }
                }
            } else {
                // diffuse
                if (scene.settings.importanceSamplingOn) {
                    float phi = 2.0 * M_PI_F * e1;
                    float theta = asin(e2);
                    Direction objSpaceRand = normalize(float3(1.*sin(theta)*cos(phi), 1.*cos(theta), 1.*sin(theta)*sin(phi)));
                    result.direction = normalize(alignHemisphereWithNormal(objSpaceRand, hit.normal));
                    result.pdf = dot(hit.normal,result.direction);
                    return result;
                } else {
                    return generateRandomOnHemi(hit.normal, float2(e1, e2));
                }
            }
            break;
        default:
            result.direction = Direction(0, 0, 0);
            result.pdf = 1;
            return result;
    }
}

Sample generateRandomOnHemi(Direction normal, float2 uv) {
    Sample result = {.direction = Direction(0,0,0), .pdf = 1.f,};
    float3 randomHemi = sampleCosineWeightedHemisphere(uv); //pick a random direction on the hemisphere
    result.direction = alignHemisphereWithNormal(randomHemi, normal); //align the random direction with the normal
    result.pdf = 1.f/(2.f*M_PI_F);
    return result;
}
