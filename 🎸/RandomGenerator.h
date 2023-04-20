#include <metal_stdlib>
using namespace metal;

struct RandomGenerator {
public:
    RandomGenerator(const thread texture2d<unsigned int> &randomTex, uint2 tid, uint frameIndex)
    // Apply a random offset to the random number index to decorrelate pixels.
        : offset(randomTex.read(tid).x + frameIndex), samplesTaken(0) {}

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
