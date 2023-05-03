#import "common.h"
#import "EmissiveList.h"
#import "tri.h"

tri EmissiveList::Iterator::operator*() const {
    return {i, scene};
}

tri EmissiveList::operator[](int i) const {
    return *(begin() + i);
}

tri EmissiveList::random() const {
    return (*this)[scene->rng() * count];
}
