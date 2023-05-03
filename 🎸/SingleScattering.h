#import "common.h"
#import "Hit.h"

struct ScatterMaterial {
    inline ScatterMaterial(const constant RenderSettings &settings, const thread Material &mat)
        : σt((settings.ssSigma_a.x + settings.ssSigma_a.y + settings.ssSigma_a.z) / 3.f + settings.ssSigma_s)
        , mat(mat)
    {}
//    float σ;
    float σt;
    
    const thread Material &mat;
    float phase(Direction out, Direction in) { return phase(dot(out, in)); }
    float phase(float cosine) { return M_1_PI_F / 4; }
};

Color singleScatter(const thread Hit &hit, const thread ScatterMaterial &mat, const thread SceneState &state);
