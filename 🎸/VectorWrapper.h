#import <metal_stdlib>

const constant float FLOAT_EPSILON = 1e-4f;

inline bool floatEpsEqual(float a, float b) {
    // If the difference between a and b is less than epsilon, they are equal
    return fabs(a - b) < FLOAT_EPSILON;
}

// To update!
// 1. Delete the “generated code” section at the bottom
// 2. Uncomment the commented section below
// 3. Run `clang -E 🎸/VectorWrapper.h`
// 4. Paste in the new generated code
// 5. Sprinkle in some `GENERATED CODE DO NOT MODIFY` comments!
// 6. Comment the original code back out

//#define VECTOR_WRAPPER(T, field0, field1, field2) \
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

//struct Color {
//    VECTOR_WRAPPER(Color, r, g, b)
//public:
//    inline Color(float3 color) : v(color.x, color.y, color.z) {
//        if (v.x < 0 || v.y < 0 || v.z < 0) {
//            v = abs(v); // ???
//        }
//    }
//
//    static inline const Color black() { return {0, 0, 0}; }
//    static inline const Color white() { return {1, 1, 1}; }
//    static inline const Color pink() { return {1, 0, 1}; }
//    static inline const Color gray(float c) { return {c, c, c}; }
//
//    inline float luminance() const {
//        // coefficients from https://stackoverflow.com/a/56678483/5244995
//        return 0.2126 * r() + 0.7152 * g() + 0.0722 * b();
//    }
//    inline Color aces_approx() const {
//        // https://graphics-programming.org/resources/tonemapping/index.html
//        auto v = (this->v * 0.6);
//        float a = 2.51;
//        float b = 0.03;
//        float c = 2.43;
//        float d = 0.59;
//        float e = 0.14;
//        auto corrected = (v*(a*v+b))/(v*(c*v+d)+e);
//        // gamma!
//        return {max(0, min(1, pow(corrected, 1 / 2.2)))};
//    }
//
//    inline Color(const thread Color &c) : v(c.v) {}
//    inline Color(const constant Color &c) : v(c.v) {}
//
//    inline Color operator * (Color other) const {
//        return {v * other.v};
//    }
//
//    inline void operator *= (Color other) {
//        v *= other.v;
//    }
//};
//
//class Location {
//    inline Location(float3 loc) : v(loc.x, loc.y, loc.z) {}
//    VECTOR_WRAPPER(Location, x, y, z)
//public:
//    float3 operator + (Location other) const {
//        return v + other.v;
//    }
//    float3 operator + (float3 other) const {
//        return {v + other};
//    }
//    float3 operator - (Location other) const {
//        return v - other.v;
//    }
//};
//
//class Direction {
//    inline Direction(float3 loc) : v(loc.x, loc.y, loc.z) {}
//    VECTOR_WRAPPER(Direction, x, y, z)
//public:
//    Direction(Location from, Location to) : Direction(to._unwrap() - from._unwrap()) {
//        this->normalize();
//    }
//    Direction(float3 from, Location to) : Direction(to._unwrap() - from) {
//        this->normalize();
//    }
//    Direction(Location from, float3 to) : Direction(to - from._unwrap()) {
//        this->normalize();
//    }
//};
//
//inline Location offset(const thread Location &source, const thread Direction &dir, float t) {
//    return Location::_wrap(source._unwrap() + dir._unwrap() * t);
//}

// GENERATED CODE DO NOT MODIFY

struct Color {
    inline Color(float3 color) : v(color.x, color.y, color.z) {
        if (v.x < 0 || v.y < 0 || v.z < 0) {
            v = abs(v);
        }
    }

protected: float3 v; public: inline Color(float r, float g, float b) : Color(float3(r, g, b)) {} inline Color() : v() {} inline float r() const { return v.x; } inline float g() const { return v.y; } inline float b() const { return v.z; } inline static Color _wrap(float3 v) { return {v}; } inline Color componentWiseProduct(const thread Color &other) const { return {v * other.v}; } inline Color cross(const thread Color &other) const { return {metal::cross(v, other.v)}; } inline float dot(const thread Color &other) const { return metal::dot(v, other.v); } inline float magnitude() const { return length(v); } inline float3 _unwrap() const { return v; } inline void normalize() { v = metal::normalize(float3()); } inline Color operator + (float o) const { return {v + float3(o, o, o)}; } inline Color operator + (const thread Color &o) const { return {v + o.v}; } inline void operator += (const thread Color &o) { v += o.v; } inline Color operator * (float o) const { return {v * o}; } inline void operator *= (float o) { v *= o; } inline Color operator / (const thread Color &o) const { return {v / o.v}; } inline Color operator / (float o) const { return {v / o}; } inline void operator /= (float o) { v /= o; } inline Color operator - () const { return {-v}; } inline operator bool() const { return magnitude() > 0.01; } inline bool epsEqual(const thread Color &other) const { return floatEpsEqual(v.x, other.v.x) && floatEpsEqual(v.y, other.v.y) && floatEpsEqual(v.z, other.v.z); }
public:
    static inline const Color black() { return {0, 0, 0}; }
    static inline const Color white() { return {1, 1, 1}; }
    static inline const Color pink() { return {1, 0, 1}; }
    static inline const Color gray(float c) { return {c, c, c}; }

    inline float luminance() const {

        return 0.2126 * r() + 0.7152 * g() + 0.0722 * b();
    }
    inline Color aces_approx() const {

        auto v = (this->v * 0.6);
        float a = 2.51;
        float b = 0.03;
        float c = 2.43;
        float d = 0.59;
        float e = 0.14;
        auto corrected = (v*(a*v+b))/(v*(c*v+d)+e);

        return {max(0, min(1, pow(corrected, 1 / 2.2)))};
    }

    inline Color(const thread Color &c) : v(c.v) {}
    inline Color(const constant Color &c) : v(c.v) {}

    inline Color operator * (Color other) const {
        return {v * other.v};
    }

    inline void operator *= (Color other) {
        v *= other.v;
    }
};

// GENERATED CODE DO NOT MODIFY
class Location {
    inline Location(float3 loc) : v(loc.x, loc.y, loc.z) {}
protected: float3 v; public: inline Location(float x, float y, float z) : Location(float3(x, y, z)) {} inline Location() : v() {} inline float x() const { return v.x; } inline float y() const { return v.y; } inline float z() const { return v.z; } inline static Location _wrap(float3 v) { return {v}; } inline Location componentWiseProduct(const thread Location &other) const { return {v * other.v}; } inline Location cross(const thread Location &other) const { return {metal::cross(v, other.v)}; } inline float dot(const thread Location &other) const { return metal::dot(v, other.v); } inline float magnitude() const { return length(v); } inline float3 _unwrap() const { return v; } inline void normalize() { v = metal::normalize(float3()); } inline Location operator + (float o) const { return {v + float3(o, o, o)}; } inline Location operator + (const thread Location &o) const { return {v + o.v}; } inline void operator += (const thread Location &o) { v += o.v; } inline Location operator * (float o) const { return {v * o}; } inline void operator *= (float o) { v *= o; } inline Location operator / (const thread Location &o) const { return {v / o.v}; } inline Location operator / (float o) const { return {v / o}; } inline void operator /= (float o) { v /= o; } inline Location operator - () const { return {-v}; } inline operator bool() const { return magnitude() > 0.01; } inline bool epsEqual(const thread Location &other) const { return floatEpsEqual(v.x, other.v.x) && floatEpsEqual(v.y, other.v.y) && floatEpsEqual(v.z, other.v.z); }
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

// GENERATED CODE DO NOT MODIFY
class Direction {
    inline Direction(float3 loc) : v(loc.x, loc.y, loc.z) {}
protected: float3 v; public: inline Direction(float x, float y, float z) : Direction(float3(x, y, z)) {} inline Direction() : v() {} inline float x() const { return v.x; } inline float y() const { return v.y; } inline float z() const { return v.z; } inline static Direction _wrap(float3 v) { return {v}; } inline Direction componentWiseProduct(const thread Direction &other) const { return {v * other.v}; } inline Direction cross(const thread Direction &other) const { return {metal::cross(v, other.v)}; } inline float dot(const thread Direction &other) const { return metal::dot(v, other.v); } inline float magnitude() const { return length(v); } inline float3 _unwrap() const { return v; } inline void normalize() { v = metal::normalize(float3()); } inline Direction operator + (float o) const { return {v + float3(o, o, o)}; } inline Direction operator + (const thread Direction &o) const { return {v + o.v}; } inline void operator += (const thread Direction &o) { v += o.v; } inline Direction operator * (float o) const { return {v * o}; } inline void operator *= (float o) { v *= o; } inline Direction operator / (const thread Direction &o) const { return {v / o.v}; } inline Direction operator / (float o) const { return {v / o}; } inline void operator /= (float o) { v /= o; } inline Direction operator - () const { return {-v}; } inline operator bool() const { return magnitude() > 0.01; } inline bool epsEqual(const thread Direction &other) const { return floatEpsEqual(v.x, other.v.x) && floatEpsEqual(v.y, other.v.y) && floatEpsEqual(v.z, other.v.z); }
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

// END GENERATED CODE DO NOT MODIFY

#undef VECTOR_WRAPPER

inline Location offset(const thread Location &source, const thread Direction &dir, float t) {
    return Location::_wrap(source._unwrap() + dir._unwrap() * t);
}

