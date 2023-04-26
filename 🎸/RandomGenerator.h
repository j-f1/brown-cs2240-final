#include <metal_stdlib>
using namespace metal;

struct RandomGenerator {
public:
    RandomGenerator(const thread texture2d<unsigned int> &randomTex, uint3 tid, uint frameIndex)
        : offset(randomTex.read(tid.xy).x * (1 + frameIndex * 2 + tid.z * 3)), samplesTaken(0) {}

    thread RandomGenerator &operator=(const thread RandomGenerator &) = delete;

    inline float operator()() {
        return RandomGenerator::halton(offset, samplesTaken++);
    }

private:
    uint offset;
    uint samplesTaken;

    /// Returns the i'th element of the Halton sequence using the d'th prime number as a
    /// base. The Halton sequence is a low discrepency sequence: the values appear
    /// random, but are more evenly distributed than a purely random sequence. Each random
    /// value used to render the image uses a different independent dimension, `d`,
    /// and each sample (frame) uses a different index `i`. To decorrelate each pixel,
    /// you can apply a random offset to `i`.
    static float halton(unsigned int i, unsigned int d);
};
