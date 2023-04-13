#import "Halton.h"

constant unsigned int primes[] = {
    2,   3,  5,  7,
    11, 13, 17, 19,
    23, 29, 31, 37,
    41, 43, 47, 53,
    59, 61, 67, 71,
    73, 79, 83, 89
};

/// Returns the i'th element of the Halton sequence using the d'th prime number as a
/// base. The Halton sequence is a low discrepency sequence: the values appear
/// random, but are more evenly distributed than a purely random sequence. Each random
/// value used to render the image uses a different independent dimension, `d`,
/// and each sample (frame) uses a different index `i`. To decorrelate each pixel,
/// you can apply a random offset to `i`.
float halton(unsigned int i, unsigned int d) {
    unsigned int b = primes[d];

    float f = 1.0f;
    float invB = 1.0f / b;

    float r = 0;

    while (i > 0) {
        f = f * invB;
        r = r + f * (i % b);
        i = i / b;
    }

    return r;
}
