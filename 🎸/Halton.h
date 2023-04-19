/// Returns the i'th element of the Halton sequence using the d'th prime number as a
/// base. The Halton sequence is a low discrepency sequence: the values appear
/// random, but are more evenly distributed than a purely random sequence. Each random
/// value used to render the image uses a different independent dimension, `d`,
/// and each sample (frame) uses a different index `i`. To decorrelate each pixel,
/// you can apply a random offset to `i`.
float halton(unsigned int i, unsigned int d);
