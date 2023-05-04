#import "common.h"
#import "Hit.h"

struct ScatterMaterial {
    inline ScatterMaterial(const constant RenderSettings &settings, const constant Material &mat)
        : σs(settings.ssSigma_s)
        , σt((settings.ssSigma_a.x + settings.ssSigma_a.y + settings.ssSigma_a.z) / 3.f + settings.ssSigma_s)
        , ior(settings.ssEta)
        , mat(mat)
    {}
    float σs;
    float σt;
    float σtc;
    float ior;

    const constant Material &mat;
    float phase(Direction out, Direction in) const { return phase(dot(out, in)); }
    float phase(float cosine) const { return M_1_PI_F / 4; }
};

Color singleScatter(const thread Hit &hit, const thread ScatterMaterial &mat, const thread SceneState &state);
