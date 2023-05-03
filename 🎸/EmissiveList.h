struct SceneState;

class EmissiveList {
public:
    struct Iterator {
        friend class EmissiveList;
        inline bool operator==(const thread Iterator &other) const { return i == other.i; }
        inline bool operator!=(const thread Iterator &other) const { return i != other.i; }
        inline void operator++() { i++; }
        inline Iterator operator+(int n) const { return {i + n, emissives, scene}; }
        tri operator*() const;
    protected:
        Iterator(int i, const constant ushort *emissives, const thread SceneState &scene)
        : i(i), emissives(emissives), scene(scene) {}
        int i;
        const constant ushort *emissives;
        const thread SceneState &scene;
    };

    tri operator[](int i) const;
    tri random() const;
    inline Iterator begin() const {
        return {0, emissives, *scene};
    }
    inline Iterator end() const {
        return {count, emissives, *scene};
    }
    inline int size() const { return count; }
    inline EmissiveList(const constant ushort *emissives, int count) : emissives(emissives), count(count) {}

    thread SceneState *scene;
private:
    const constant ushort  *emissives;
    const int               count;
};
