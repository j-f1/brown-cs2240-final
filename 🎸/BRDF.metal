#import "BRDF.h"
#import "common.h"
#import "Sampler.h"

//TODO eventually turn the outDir type to Ray because we will be in BSSDF land
Color getBRDF(const thread ray &inRay, const thread Direction normal, const thread Direction &outDir, const thread Material &mat, thread SceneState &scene) {
    //TODO COCO
    switch (mat.illum) {
        case Illum::refract_fresnel:
        case Illum::glass:
            return float3(1.f,1.f,1.f);
            break;
        case Illum::diffuse_specular_fresnel:
        case Illum::diffuse_specular:
            if (any(mat.specular > 0)) { //todo does this work?
                if (mat.shininess > 100) {
                    // [mirror BRDF];
                    return float3(1.f,1.f,1.f);
                } else {
                    // [Phong Glossy Specular BRDF];
                    float n = mat.shininess;
                    float3 s = mat.specular;
                    float3 normalized_color = ((n+2.f)/(2.f*M_PI_F))*s;
                    Direction norm = normalize(normal);
                    Direction reflectedVector = normalize(inRay.direction) - 2.f*dot(normalize(inRay.direction), norm)*norm;
                    float dotProd = dot(reflectedVector, normalize(outDir));
                    if (dotProd < 0) {return float3(0.f, 0.f, 0.f);}
                    float reflectiveIntensity = pow(dotProd, n);
                    
                    return normalized_color*reflectiveIntensity;
                }
            } else {
                // [diffuse BRDF];
                if (scene.settings.diffuseOn) {
                    return mat.diffuse/M_PI_F;
                } else {return float3(1.f,1.f,1.f);}
            }
            break;
        default:
            return 0.f; //TODO REMOVE
            break;
    }
}

Sample getNextDirection(const thread Location &intersectionPoint, const thread Direction normal, const thread Material &mat, const thread ray &inRay, thread SceneState &scene) {
    
    float e1 = scene.rng(); //random number
    float e2 = scene.rng(); //random number
    
    //TODO COCO
    Sample result = {.direction = Direction(0,0,0), .pdf = 1.f, .reflection = false,};
    switch (mat.illum) {
        case Illum::refract_fresnel:
        case Illum::glass:
            // glass
            {
                float3 norm = normal;
                float cos_theta_i = dot(norm, inRay.direction);
                bool passingIntoGlass = cos_theta_i < 0;
                
                float ior = mat.ior;//Diffuse color as array of floats
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
                    Direction incomingDir = normalize(inRay.direction);
                    Direction reflectedVector = incomingDir - 2.f*dot(incomingDir,norm)*norm;
                    result.direction = reflectedVector;
                    result.pdf = 1.f;
                    result.reflection = true;
                } else {
                    //refract
                    float cosTheta_t = sqrt(sqdCos_t);
                    float ratioIT = ior_i/ior_t;
                    //if the determinant is non-negative, we do not have total internal reflection
                    Direction refractedDir = ratioIT * inRay.direction + (ratioIT * cos_theta_i - cosTheta_t)*norm;
                    
                    //accumulate the radiance of the next path!
                    result.direction = refractedDir;
                    result.pdf = 1.f;
                    
                }
                return result;
            }
            break;
        case Illum::diffuse_specular_fresnel:
        case Illum::diffuse_specular:
            if (any(mat.specular>0)) {
                if (mat.shininess > 100) {
                    // mirror
                    if (scene.settings.mirrorOn) {
                        Direction reflectedVector = inRay.direction - 2.f*dot(inRay.direction, normal)*normal;
                        result.direction = reflectedVector;
                        result.pdf = 1.f;
                        result.reflection = true;
                        return result;
                    } else {
                        return generateRandomOnHemi(normal, float2(e1, e2));
                    }
                } else {
                    // specular BRDF;
                    if (scene.settings.importanceSamplingOn) {
                        //TODO
                        float shine = mat.shininess;

                        float phi = 2.0 * M_PI_F * e1;
                        float theta = acos(pow(e2, 1/(1+shine)));

                        Direction objSpaceRand = float3(1.*sin(theta)*cos(phi), 1.*cos(theta), 1.*sin(theta)*sin(phi));

                        result.pdf = (shine+2.f)/(2.f*M_PI_F)*(pow(cos(theta),shine));

                        Direction reflectedVector = inRay.direction - 2.f*(dot(inRay.direction,normal))*normal;

                        result.direction = alignHemisphereWithNormal(objSpaceRand, reflectedVector);

                        return result;
                    } else {
                        return generateRandomOnHemi(normal, float2(e1, e2));
                    }
                }
            } else {
                // diffuse
                if (scene.settings.importanceSamplingOn) {
                    float phi = 2.0 * M_PI_F * e1;
                    float theta = asin(e2);
                    Direction objSpaceRand = normalize(float3(1.*sin(theta)*cos(phi), 1.*cos(theta), 1.*sin(theta)*sin(phi)));
                    result.direction = normalize(alignHemisphereWithNormal(objSpaceRand, normalize(normal)));
                    result.pdf = dot(normalize(normal),result.direction);
                    return result;
                } else {
                    return generateRandomOnHemi(normal, float2(e1, e2));
                }
            }
            break;
        default:
            result.direction = Direction(0, 0, 0);
            result.pdf = 1;
            return result;
            break;
    }
}

//generate the smooth normal??
Direction generateWeightedNormal(thread Intersector::Intersection intersection, thread SceneState& scene) {
    tri hit{intersection.index(), scene};

    if (floatEpsEqual(length_squared(hit.n1), 0) || floatEpsEqual(length_squared(hit.n2), 0) || floatEpsEqual(length_squared(hit.n3), 0)) {
        return hit.faceNormal;
    }

    Location v0 = hit.v2 - hit.v1;
    Location v1 = hit.v3 - hit.v1;
    Location v2 = intersection.location() - hit.v1;
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



Sample generateRandomOnHemi(Direction normal, float2 uv) {
    Sample result = {.direction = Direction(0,0,0), .pdf = 1.f,};
    float3 randomHemi = sampleCosineWeightedHemisphere(uv); //pick a random direction on the hemisphere
    result.direction = alignHemisphereWithNormal(randomHemi, normal); //align the random direction with the normal
    result.pdf = 1.f/(2.f*M_PI_F);
    return result;
}
