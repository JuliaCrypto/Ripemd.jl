# Ripemd.jl

[![Build Status](https://travis-ci.org/JuliaCrypto/Ripemd.jl.svg?branch=master)](https://travis-ci.org/JuliaCrypto/Ripemd.jl)
[![codecov.io](http://codecov.io/github/JuliaCrypto/Ripemd.jl/coverage.svg?branch=master)](http://codecov.io/github/JuliaCrypto/Ripemd.jl?branch=master)

Pure Julia implementation of the [Ripemd](https://en.wikipedia.org/wiki/RIPEMD) hashing algorithm.
Currently only Ripemd160 is implemented and convenience functions are missing.

## Usage

### Hashing a single message

`ripemd160` accepts a byte vector, a tuple of bytes, or a string and returns
the 20-byte digest as a `Vector{UInt8}`:

```julia
julia> using Ripemd

julia> bytes2hex(ripemd160(b"test"))
"5e52fee47e6b070565f74372468cdc699de89107"

julia> bytes2hex(ripemd160("test"))
"5e52fee47e6b070565f74372468cdc699de89107"
```

Large or streamed input can be fed incrementally through a context:

```julia
julia> ctx = RIPEMD160_CTX();

julia> update!(ctx, b"te");

julia> update!(ctx, b"st");

julia> bytes2hex(digest!(ctx))
"5e52fee47e6b070565f74372468cdc699de89107"
```

### Batch hashing

When many independent messages have to be hashed, the batch API hashes all of
them in one call. It runs on all Julia threads on the CPU (start Julia with
`-t auto` or `-t N`) and, with AMDGPU.jl loaded, on AMD GPUs (see below).

All batch methods return a `20 × N` `Matrix{UInt8}` whose column `i` is the
digest of message `i`. Get individual digests with `out[:, i]` or iterate over
`eachcol(out)`.

**Fixed-length messages** are the columns of a `Matrix{UInt8}`:

```julia
julia> msgs = rand(UInt8, 64, 1000);    # 1000 messages of 64 bytes each

julia> digests = ripemd160(msgs);       # 20 × 1000 Matrix{UInt8}

julia> digests[:, 7] == ripemd160(msgs[:, 7])
true
```

**Variable-length (ragged) messages** are stored back to back in one
`Vector{UInt8}` together with a vector of `N + 1` zero-based byte offsets:
message `i` is `data[offsets[i] + 1 : offsets[i + 1]]`. `offsets[1]` is `0`
and `offsets[end]` is `length(data)`. Empty messages are allowed (two equal
consecutive offsets). Offsets may be any integer type, e.g. `Int32` to save
memory on the GPU.

```
data     = [a b c | d e | | f]          (message 3 is empty)
offsets  = [0, 3, 5, 5, 6]
```

`pack_messages` builds this layout from any collection of strings or byte
vectors:

```julia
julia> data, offsets = pack_messages(["abc", "de", "", "f"]);

julia> data, offsets
(UInt8[0x61, 0x62, 0x63, 0x64, 0x65, 0x66], [0, 3, 5, 5, 6])

julia> digests = ripemd160(data, offsets);   # 20 × 4 Matrix{UInt8}

julia> bytes2hex(digests[:, 1])
"8eb208f7e05d987a9b044a8e98c6b087f15a0bfc"

julia> bytes2hex(digests[:, 3]) == bytes2hex(ripemd160(""))
true
```

If your data is already contiguous, e.g. fixed-size records in a buffer, there
is no need to copy: build the offsets directly.

```julia
julia> buf = rand(UInt8, 32 * 100_000);          # 100k records of 32 bytes

julia> offsets = 0:32:length(buf);               # any AbstractVector of integers

julia> ripemd160(buf, offsets) == ripemd160(reshape(buf, 32, :))
true
```

The batch functions give exactly the same digests as the single-message API;
they only differ in how the work is scheduled.

### AMDGPU backend

Loading [AMDGPU.jl](https://github.com/JuliaGPU/AMDGPU.jl) next to Ripemd
activates a package extension. The batch functions then accept `ROCArray`s and
launch a kernel in which every GPU work-item hashes one message:

| input                                       | result               |
|---------------------------------------------|----------------------|
| `ripemd160(msgs::ROCMatrix{UInt8})`         | `ROCMatrix{UInt8}` 20 × N |
| `ripemd160(data::ROCVector{UInt8}, offsets::ROCVector{<:Integer})` | `ROCMatrix{UInt8}` 20 × N |
| `ripemd160(msg::ROCVector{UInt8})`          | `ROCVector{UInt8}` of length 20 (single message) |

```julia
julia> using Ripemd, AMDGPU

julia> msgs = rand(UInt8, 64, 1_000_000);

julia> gmsgs = ROCArray(msgs);              # upload

julia> gdigests = ripemd160(gmsgs);         # 20 × 1000000 ROCMatrix{UInt8}

julia> digests = Array(gdigests);           # download, waits for the kernel

julia> digests == ripemd160(msgs)
true
```

Ragged input works the same way, upload both arrays:

```julia
julia> data, offsets = pack_messages(readlines("words.txt"));

julia> gdigests = ripemd160(ROCArray(data), ROCArray(Int32.(offsets)));

julia> bytes2hex.(eachcol(Array(gdigests)))
```

Notes:

* Kernel launches are asynchronous. `Array(gdigests)` (or
  `AMDGPU.synchronize()`) waits for the result. Anything you do with
  `gdigests` on the GPU, e.g. broadcasting or a comparison against a
  `ROCArray` of expected digests, is ordered after the kernel automatically.
* The output is a plain `ROCMatrix{UInt8}`, so it can be consumed by further
  GPU code without a round trip to the host.
* Uploading the messages and downloading the digests costs about 2-3x the
  kernel time for short messages on an APU. The GPU pays off when the data
  already lives on the device or when batches are large.
* The GPU is saturated from roughly 100,000 messages upwards; for a handful
  of messages the CPU batch API is faster.
* Every work-item processes its message sequentially, so one very long
  message alone does not benefit from the GPU. Many messages do.
* Messages of any length, including 0, and offsets in any position are
  supported. No alignment requirements.

#### Tests and benchmark

The GPU tests and the benchmark need a working ROCm installation and use
their own environment in `test/amdgpu/` (add `BenchmarkTools` to it for the
benchmark):

```
julia --project=test/amdgpu -e 'using Pkg; Pkg.develop(path="."); Pkg.add(["AMDGPU", "BenchmarkTools"])'
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
