#import <metal_stdlib>

const constant float FLOAT_EPSILON = 1e-4f;

inline bool floatEpsEqual(float a, float b) {
    // If the difference between a and b is less than epsilon, they are equal
    return fabs(a - b) < FLOAT_EPSILON;
}


#define VECTOR_WRAPPER(T, field0, field1, field2) \
    protected:                                              \
        float3 v;                                           \
    public:                                                 \
        inline T(float field0, float field1, float field2)  \
            : T(float3(field0, field1, field2)) {}          \
        inline T() : v() {}                                 \
        inline float field0() const { return v.x; }         \
        inline float field1() const { return v.y; }         \
        inline float field2() const { return v.z; }         \
        inline static T _wrap(float3 v) { return {v}; }     \
        inline T componentWiseProduct(const thread T &other) const { return {v * other.v}; }  \
        inline T cross(const thread T &other) const {       \
            return {metal::cross(v, other.v)};              \
        }                                                   \
        inline float dot(const thread T &other) const {     \
            return metal::dot(v, other.v);                  \
        }                                                   \
        inline float magnitude() const {                    \
            return length(v);                               \
        }                                                   \
        inline float3 _unwrap() const { return v; }         \
        inline void normalize() {                           \
            v = metal::normalize(float3());                 \
        }                                                   \
        inline T operator + (float o) const {               \
            return {v + float3(o, o, o)};                   \
        }                                                   \
        inline T operator + (const thread T &o) const {     \
            return {v + o.v};                               \
        }                                                   \
        inline void operator += (const thread T &o) {       \
            v += o.v;                                       \
        }                                                   \
        inline T operator * (float o) const {               \
            return {v * o};                                 \
        }                                                   \
        inline void operator *= (float o) {                 \
            v *= o;                                         \
        }                                                   \
        inline T operator / (const thread T &o) const {     \
            return {v / o.v};                               \
        }                                                   \
        inline T operator / (float o) const {               \
            return {v / o};                                 \
        }                                                   \
        inline void operator /= (float o) {                 \
            v /= o;                                         \
        }                                                   \
        inline T operator - () const {                      \
            return {-v};                                    \
        }                                                   \
        inline operator bool() const {                      \
            return magnitude() > 0.01;                      \
        }                                                   \
        inline bool epsEqual(const thread T &other) const { \
            return floatEpsEqual(v.x, other.v.x)            \
            && floatEpsEqual(v.y, other.v.y)                \
            && floatEpsEqual(v.z, other.v.z);               \
        }

struct Color {
    VECTOR_WRAPPER(Color, r, g, b)
public:
    inline Color(float3 color) : v(color.x, color.y, color.z) {
        if (v.x < 0 || v.y < 0 || v.z < 0) {
            v = abs(v); // ???
        }
    }

    static inline const Color black() { return {0, 0, 0}; }
    static inline const Color white() { return {1, 1, 1}; }
    static inline const Color pink() { return {1, 0, 1}; }
    static inline const Color gray(float c) { return {c, c, c}; }

    inline float luminance() const {
        // coefficients from https://stackoverflow.com/a/56678483/5244995
        return 0.2126 * r() + 0.7152 * g() + 0.0722 * b();
    }
    inline Color aces_approx() const {
        // https://graphics-programming.org/resources/tonemapping/index.html
        auto v = (this->v * 0.6);
        float a = 2.51;
        float b = 0.03;
        float c = 2.43;
        float d = 0.59;
        float e = 0.14;
        auto corrected = (v*(a*v+b))/(v*(c*v+d)+e);
        // gamma!
        return {max(0, min(1, pow(corrected, 1 / 2.2)))};
    }
};

class Location {
    inline Location(float3 loc) : v(loc.x, loc.y, loc.z) {}
    VECTOR_WRAPPER(Location, x, y, z)
public:
    float3 operator + (Location other) const {
        return v + other.v;
    }
    float3 operator + (float3 other) const {
        return {v + other};
    }
    float3 operator - (Location other) const {
        return v - other.v;
    }
};

class Direction {
    inline Direction(float3 loc) : v(loc.x, loc.y, loc.z) {}
    VECTOR_WRAPPER(Direction, x, y, z)
public:
    Direction(Location from, Location to) : Direction(to._unwrap() - from._unwrap()) {
        this->normalize();
    }
    Direction(float3 from, Location to) : Direction(to._unwrap() - from) {
        this->normalize();
    }
    Direction(Location from, float3 to) : Direction(to - from._unwrap()) {
        this->normalize();
    }
};

inline Location offset(const thread Location &source, const thread Direction &dir, float t) {
    return Location::_wrap(source._unwrap() + dir._unwrap() * t);
}


#undef VECTOR_WRAPPER
