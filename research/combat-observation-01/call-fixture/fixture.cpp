// SPDX-License-Identifier: MPL-2.0
#define NOMINMAX
#include <Windows.h>

#include <array>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <limits>
#include <mutex>
#include <shared_mutex>
#include <thread>

using Bytes = std::array<unsigned char, 5>;

struct Sample {
    int count = 0;
    float delta = 0.0f;
    unsigned tag = 0;
};

extern "C" {
extern unsigned char CallSite, Continuation;
int Invoke(Sample* sample, float delta, unsigned tag);
void Relay();
}

static void require(bool result, const char* check)
{
    if (!result) {
        std::fprintf(stderr, "FAIL: %s\n", check);
        std::exit(1);
    }
}

static std::shared_mutex admission;
static HANDLE entered, releaseWriter;

struct WriterException {};
constexpr DWORD FixtureExceptionCode = 0xE0425310;

extern "C" __declspec(noinline) int Writer(Sample* sample, float delta, unsigned tag)
{
    ++sample->count;
    sample->delta = delta;
    sample->tag = tag;
    if (tag == 8) {
        require(SetEvent(entered) != 0, "signal writer entry");
        require(WaitForSingleObject(releaseWriter, 10000) == WAIT_OBJECT_0, "writer release");
    }
    if (tag == 9)
        throw WriterException{};
    if (tag == 10)
        RaiseException(FixtureExceptionCode, EXCEPTION_NONCONTINUABLE, 0, nullptr);
    return static_cast<int>(delta * 4) + static_cast<int>(tag);
}

extern "C" __declspec(noinline) int Wrapper(Sample* sample, float delta, unsigned tag)
{
    // Force a real unwindable frame across the call, including in optimized builds.
    volatile int result = Writer(sample, delta - 2.0f, tag);
    return result;
}

static int run(Sample& sample, unsigned tag)
{
    std::shared_lock lock(admission);
    return Invoke(&sample, -3.25f, tag);
}

static bool catchesFixtureSeh(Sample& sample)
{
    __try {
        run(sample, 10);
    } __except (GetExceptionCode() == FixtureExceptionCode
            ? EXCEPTION_EXECUTE_HANDLER : EXCEPTION_CONTINUE_SEARCH) {
        return true;
    }
    return false;
}

static bool encode(std::uintptr_t destination, Bytes& bytes)
{
    const auto next = reinterpret_cast<std::uintptr_t>(&Continuation);
    const auto distance = destination >= next ? destination - next : next - destination;
    const auto limit = static_cast<std::uintptr_t>(std::numeric_limits<std::int32_t>::max());
    if (distance > limit + (destination < next ? 1u : 0u))
        return false;
    const auto signedDistance = static_cast<std::int64_t>(distance);
    const auto displacement = static_cast<std::int32_t>(
        destination >= next ? signedDistance : -signedDistance);
    bytes[0] = 0xE8;
    std::memcpy(bytes.data() + 1, &displacement, sizeof displacement);
    return true;
}

enum class Result { ok, busy, state, bytes, range };

class FixturePatch {
public:
    Result install(const Bytes& expected, std::uintptr_t relay)
    {
        std::unique_lock lock(admission, std::try_to_lock);
        if (!lock) return Result::busy;
        if (installed) return Result::state;
        if (!matches(expected)) return Result::bytes;
        Bytes replacement{};
        if (!encode(relay, replacement)) return Result::range;
        write(replacement);
        original = expected;
        patched = replacement;
        installed = true;
        return Result::ok;
    }

    Result remove()
    {
        std::unique_lock lock(admission, std::try_to_lock);
        if (!lock) return Result::busy;
        if (!installed) return Result::state;
        if (!matches(patched)) return Result::bytes;
        write(original);
        installed = false;
        return Result::ok;
    }

    static bool matches(const Bytes& bytes)
    {
        return std::memcmp(&CallSite, bytes.data(), bytes.size()) == 0;
    }

private:
    static void write(const Bytes& bytes)
    {
        DWORD previous, ignored;
        require(VirtualProtect(&CallSite, bytes.size(), PAGE_EXECUTE_READWRITE, &previous) != 0,
            "make fixture site writable");
        std::memcpy(&CallSite, bytes.data(), bytes.size());
        require(VirtualProtect(&CallSite, bytes.size(), previous, &ignored) != 0,
            "restore fixture page protection");
        require(FlushInstructionCache(GetCurrentProcess(), &CallSite, bytes.size()) != 0,
            "flush fixture instruction cache");
        require(matches(bytes), "read back fixture bytes");
    }

    Bytes original{}, patched{};
    bool installed = false;
};

int main()
{
    static_assert(sizeof(void*) == 8);
    const auto site = reinterpret_cast<std::uintptr_t>(&CallSite);
    const auto next = reinterpret_cast<std::uintptr_t>(&Continuation);
    const auto relay = reinterpret_cast<std::uintptr_t>(&Relay);
    require(next - site == 5, "five-byte CALL and continuation");
    DWORD64 base{};
    require(RtlLookupFunctionEntry(site, &base, nullptr) != nullptr, "caller unwind entry");
    require(RtlLookupFunctionEntry(reinterpret_cast<DWORD64>(&Wrapper), &base, nullptr) != nullptr,
        "wrapper unwind entry");

    Bytes original{}, patch{};
    require(encode(reinterpret_cast<std::uintptr_t>(&Writer), original), "writer reachable");
    require(encode(relay, patch) && original != patch, "relay reachable");
    require(FixturePatch::matches(original), "original CALL targets writer");

    FixturePatch fixture;
    Sample sample;
    require(run(sample, 7) == -6 && sample.count == 1 && sample.delta == -3.25f && sample.tag == 7,
        "baseline arguments, return and ABI");
    Bytes wrong = original;
    wrong[1] ^= 1;
    require(fixture.install(wrong, relay) == Result::bytes && FixturePatch::matches(original),
        "wrong expected bytes refused");
    require(fixture.install(original, next + 0x80000000ULL) == Result::range &&
        FixturePatch::matches(original), "unreachable relay refused");
    require(fixture.install(original, relay) == Result::ok, "install");
    require(fixture.install(original, relay) == Result::state && FixturePatch::matches(patch),
        "repeat install refused");
    require(run(sample, 7) == -14 && sample.count == 2 && sample.delta == -5.25f && sample.tag == 7,
        "only float changed, writer once, return and ABI");

    entered = CreateEventW(nullptr, TRUE, FALSE, nullptr);
    releaseWriter = CreateEventW(nullptr, TRUE, FALSE, nullptr);
    require(entered && releaseWriter, "create writer events");
    Sample workerSample;
    std::thread worker([&] { require(run(workerSample, 8) == -13, "active call returns"); });
    require(WaitForSingleObject(entered, 10000) == WAIT_OBJECT_0, "wait for writer");
    require(fixture.remove() == Result::busy && FixturePatch::matches(patch), "active removal refused");
    require(SetEvent(releaseWriter) != 0, "release writer");
    worker.join();
    require(workerSample.count == 1, "active writer called once");
    CloseHandle(releaseWriter);
    CloseHandle(entered);

    bool caught = false;
    try {
        run(sample, 9);
    } catch (const WriterException&) {
        caught = true;
    }
    require(caught && sample.count == 3, "exception unwound across wrapper and assembly caller");
    require(catchesFixtureSeh(sample) && sample.count == 4, "SEH unwound across the same frames");
    require(fixture.remove() == Result::ok && FixturePatch::matches(original),
        "remove after unwind and restore original bytes");
    require(run(sample, 7) == -6 && sample.count == 5 && sample.delta == -3.25f && sample.tag == 7,
        "restored arguments, return and ABI");
    std::puts("PASS: rel32 CALL, ABI, refusal checks, active removal, C++/SEH unwind and restore");
}
