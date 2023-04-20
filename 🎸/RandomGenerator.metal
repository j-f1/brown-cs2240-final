#import "RandomGenerator.h"

static constexpr constant unsigned int primes[] = {
    2,   3,  5,  7,
    11, 13, 17, 19,
    23, 29, 31, 37,
    41, 43, 47, 53,
    59, 61, 67, 71,
    73, 79, 83, 89
};

float RandomGenerator::halton(unsigned int i, unsigned int d) {
    assert(d < sizeof(primes) / sizeof(primes[0]));
    unsigned int base = primes[d];

    float coeff = 1.0f;
    float invBase = 1.0f / base;

    float rand = 0;

    while (i > 0) {
        coeff *= invBase;
        rand += coeff * (i % base);
        i /= base;
    }

    return rand;
}
