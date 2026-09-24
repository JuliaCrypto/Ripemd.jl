# Throughput comparison of the three ways to hash a batch of messages:
#   1. streaming CPU API, one message at a time, single thread
#   2. batch CPU API, Threads.nthreads() threads
#   3. batch AMDGPU API (kernel only, and including host<->device copies)
#
# Run with
#   julia -t auto --project=test/amdgpu perf/perf_amdgpu.jl

using Ripemd
using AMDGPU
using BenchmarkTools
using Printf
using Random

AMDGPU.functional() || error("AMDGPU is not functional on this machine")

# Run `f` for about a second first so the GPU clocks ramp up (short kernels on
# an idle GPU otherwise measure 2-3x slower), then take the best of 3 x 10 runs.
function bench(f, args...)
    t0 = time()
    while time() - t0 < 1.0
        f(args...)
    end
    t = Inf
    for _ in 1:3
        t = min(t, @belapsed $f($(args)...) samples=10 evals=1)
    end
    return t
end

# GPU: synchronize after the kernel so we time the whole thing
function gpu_kernel(gm)
    out = ripemd160(gm)
    AMDGPU.synchronize()
    return out
end
function gpu_kernel(gd, go)
    out = ripemd160(gd, go)
    AMDGPU.synchronize()
    return out
end
gpu_roundtrip(m::Matrix) = Array(gpu_kernel(ROCArray(m)))
gpu_roundtrip(d::Vector, o::Vector) = Array(gpu_kernel(ROCArray(d), ROCArray(o)))

cpu_stream(m::Matrix) = [ripemd160(m[:, i]) for i in 1:size(m, 2)]
cpu_stream(d::Vector, o::Vector) = [ripemd160(d[o[i]+1:o[i+1]]) for i in 1:length(o)-1]

println("Julia $(VERSION), $(Threads.nthreads()) threads, ",
        AMDGPU.HIP.name(AMDGPU.device()))

@printf("%-34s %10s %12s %12s %10s\n", "case", "n", "MB", "Mhash/s", "GB/s")
function report(name, n, bytes, t)
    @printf("%-34s %10d %12.1f %12.3f %10.2f\n", name, n, bytes / 1e6,
            n / t / 1e6, bytes / t / 1e9)
end

Random.seed!(0)
for (len, n) in ((32, 2_000_000), (64, 2_000_000), (128, 1_000_000),
                 (1024, 200_000), (16384, 20_000))
    m = rand(UInt8, len, n)
    gm = ROCArray(m)
    gpu_kernel(gm) # warm up / compile
    bytes = length(m)
    println("\n--- fixed length $len bytes, $n messages ---")
    n_s = min(n, 100_000) # streaming is slow, use a subset
    report("CPU streaming (1 thread)", n_s, len * n_s, bench(cpu_stream, m[:, 1:n_s]))
    report("CPU batch ($(Threads.nthreads()) threads)", n, bytes, bench(ripemd160, m))
    report("GPU kernel", n, bytes, bench(gpu_kernel, gm))
    report("GPU incl. transfers", n, bytes, bench(gpu_roundtrip, m))
    @assert Array(ripemd160(gm)) == ripemd160(m)
end

# ragged messages of random length
let n = 2_000_000
    msgs = [rand(UInt8, rand(0:200)) for _ in 1:n]
    data, offs = pack_messages(msgs)
    gd, go = ROCArray(data), ROCArray(offs)
    gpu_kernel(gd, go)
    bytes = length(data)
    println("\n--- ragged, lengths uniform in 0:200, $n messages ---")
    n_s = 100_000
    report("CPU streaming (1 thread)", n_s, offs[n_s + 1],
           bench(cpu_stream, data, offs[1:n_s + 1]))
    report("CPU batch ($(Threads.nthreads()) threads)", n, bytes, bench(ripemd160, data, offs))
    report("GPU kernel", n, bytes, bench(gpu_kernel, gd, go))
    report("GPU incl. transfers", n, bytes, bench(gpu_roundtrip, data, offs))
    @assert Array(ripemd160(gd, go)) == ripemd160(data, offs)
end
