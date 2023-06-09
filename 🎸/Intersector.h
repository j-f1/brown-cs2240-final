#import "VectorWrapper.h"

struct Material;
struct SceneState;
struct tri;

struct Intersector {
private:
    intersector<triangle_data> i;
    const thread primitive_acceleration_structure &accelerationStructure;
public:
    struct Intersection {
        friend struct Intersector;
    protected:
        Intersection(ray inRay, intersector<triangle_data>::result_type i) : ray(inRay), i(i) {}
        intersector<triangle_data>::result_type i;
    public:
        ray ray;
        inline operator bool() const {
            return i.type != intersection_type::none;
        }
        inline int index() const {
            return i.primitive_id;
        }
        const tri tri(const thread SceneState &scene) const;
        const constant Material &material(const thread SceneState &scene) const;
        inline float distance() const {
            return i.distance;
        }
        inline Location location() const {
            return ray.origin + ray.direction * distance();
        }
    };

    Intersector(const thread primitive_acceleration_structure &accelerationStructure)
    : i(), accelerationStructure(accelerationStructure)
    {
        // not using intersection functions, so some hints to Metal for better performance.
        i.assume_geometry_type(geometry_type::triangle);
        i.force_opacity(forced_opacity::opaque);

        // Get the closest intersection, not the first intersection.
        // (this is the default)
        i.accept_any_intersection(false);
    }

    Intersection operator()(const thread ray &ray) const {
        return {ray, i.intersect(ray, accelerationStructure)};
    }
};
