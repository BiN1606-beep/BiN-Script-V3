/*
    this time i know what im doing, trust
*/

#include <iostream>
#include <cstdint>
#include <cctype>
#include <vector>
#include <string_view>
#include <unordered_set>
#include <unordered_map>
#include <cstring>
#include <optional>
#include <memory>
#include <variant>



constexpr auto WAIT_FOR_EXIT = 0;
constexpr auto REQUIRE_SEMICOLON = 1;

char* TEXT =
"var x: sint64 = 3;\n"
"_print x + 5;"
;



/*
    utils
*/

void CRASH_THE_FUCKING_PROGRAM() {
    CRASH_THE_FUCKING_PROGRAM();
}

void doIndent(std::ostream& os, size_t indent) {
    while (indent--)
        os << "  ";
}

namespace BiN {

    /*
        straight from copilot
    */

    // UniqueVariant holds exactly one std::unique_ptr<T> for some T in Ts...
    // Index 0 of the variant is std::monostate (empty), indices 1..N map to Ts...
    template <class... Ts>
    class UniqueVariant {
        std::variant<std::monostate, std::unique_ptr<Ts>...> data;

    public:
        UniqueVariant() = default;
        UniqueVariant(UniqueVariant&&) = default;
        UniqueVariant& operator=(UniqueVariant&&) = default;
        UniqueVariant(const UniqueVariant&) = delete;
        UniqueVariant& operator=(const UniqueVariant&) = delete;

        // set from a unique_ptr
        template <class T>
        void set(std::unique_ptr<T> p) {
            static_assert((std::is_same_v<T, Ts> || ...), "T must be one of Ts...");
            data = std::move(p);
        }

        // construct in-place
        template <class T, class... Args>
        T* emplace(Args&&... args) {
            static_assert((std::is_same_v<T, Ts> || ...), "T must be one of Ts...");
            data = std::make_unique<T>(std::forward<Args>(args)...);
            return get<T>();
        }

        // assign from a temporary unique_ptr
        template <class T>
        UniqueVariant& operator=(std::unique_ptr<T> p) {
            set<T>(std::move(p));
            return *this;
        }

        // get raw pointer for the stored type T (or nullptr)
        template <class T>
        T* get() {
            static_assert((std::is_same_v<T, Ts> || ...), "T must be one of Ts...");
            if (auto ptr = std::get_if<std::unique_ptr<T>>(&data))
                return ptr->get();
            return nullptr;
        }

        // release the unique_ptr if it holds T, otherwise nullptr
        template <class T>
        std::unique_ptr<T> release() {
            static_assert((std::is_same_v<T, Ts> || ...), "T must be one of Ts...");
            if (auto ptr = std::get_if<std::unique_ptr<T>>(&data))
                return std::move(*ptr);
            return nullptr;
        }

        void reset() { data = std::monostate{}; }

        // variant index: 0 == empty, 1..N correspond to Ts in order
        size_t index() const noexcept { return data.index(); }
    };



    template<class T, class U>
    class BaseStream {
    public:
        virtual T peek() = 0;
        virtual T eat() = 0;

        virtual U newCheckpoint() = 0;
        virtual void gotoCheckpoint(U k) = 0;

        virtual void reset() = 0;
    };



    template<class T>
    class VectorStream : public BaseStream<T, size_t> {
    private:
        std::vector<T> data{};
        size_t pos = 0;

    public:
        virtual T peek() override {
            if (pos < data.size())
                return data[pos];

            return T{};
        }

        virtual T eat() override {
            if (pos < data.size())
                return data[pos++];

            return T{};
        }

        virtual size_t newCheckpoint() override {
            return pos;
        }

        virtual void gotoCheckpoint(size_t k) override {
            pos = k;
        }

        virtual void reset() override {
            pos = 0;
        }
    };

}



/*
    user
*/

int main (int argc, char** argv) {
    std::cout << "Hello, world!\n";

    return 0;
}