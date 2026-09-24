# Ripemd.jl

[![Build Status](https://travis-ci.org/JuliaCrypto/Ripemd.jl.svg?branch=master)](https://travis-ci.org/JuliaCrypto/Ripemd.jl)
[![codecov.io](http://codecov.io/github/JuliaCrypto/Ripemd.jl/coverage.svg?branch=master)](http://codecov.io/github/JuliaCrypto/Ripemd.jl?branch=master)

Pure Julia implementation of the [Ripemd](https://en.wikipedia.org/wiki/RIPEMD) hashing algorithm.
Currently only Ripemd160 is implemented and convenience functions are missing.

Usage is very simple:
```julia
julia> using Ripemd

julia> bytes2hex(ripemd160(b"test"))
"5e52fee47e6b070565f74372468cdc699de89107"
```

## Batch hashing

Many messages can be hashed at once. Messages are either the columns of a
`Matrix{UInt8}` (fixed length) or stored back to back in a `Vector{UInt8}`
with a vector of `N + 1` zero-based offsets (ragged). The result is a
`20 × N` byte matrix. On the CPU this uses all Julia threads.

```julia
julia> data, offsets = pack_messages(["", "a", "abc"]);

julia> digests = ripemd160(data, offsets);   # 20 × 3 Matrix{UInt8}

julia> bytes2hex(digests[:, 3])
"8eb208f7e05d987a9b044a8e98c6b087f15a0bfc"

julia> ripemd160(rand(UInt8, 64, 1000))     # 1000 messages of 64 bytes
```

### AMDGPU backend

With [AMDGPU.jl](https://github.com/JuliaGPU/AMDGPU.jl) loaded, the same
functions accept `ROCArray`s and run one work-item per message on the GPU:

```julia
julia> using Ripemd, AMDGPU

julia> digests = ripemd160(ROCArray(data), ROCArray(offsets));  # ROCMatrix{UInt8}

julia> ripemd160(ROCArray(rand(UInt8, 64, 1_000_000)))
```

The GPU tests live in `test/amdgpu/` and a throughput comparison against the
CPU in `perf/perf_amdgpu.jl`:

```
julia --project=test/amdgpu test/amdgpu/runtests.jl
julia -t auto --project=test/amdgpu perf/perf_amdgpu.jl
```

Measured on a Radeon 8060S (gfx1151, 40 CUs) against a 16-core / 32-thread
CPU, kernel time only (host-device copies add roughly 2-3x for short
messages on this APU):

| message length | messages  | CPU 1 thread | CPU 32 threads | GPU kernel |
|---------------:|----------:|-------------:|---------------:|-----------:|
|       32 bytes | 2,000,000 |  4.9 Mhash/s |   105 Mhash/s  | 1066 Mhash/s |
|       64 bytes | 2,000,000 |  2.7 Mhash/s |    59 Mhash/s  | 1035 Mhash/s |
|     1024 bytes |   200,000 |   0.37 GB/s  |    7.5 GB/s    |   91 GB/s  |

The GPU needs on the order of 100k messages in flight to be saturated.
