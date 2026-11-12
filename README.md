# Ripemd.jl

[![CI](https://github.com/JuliaCrypto/Ripemd.jl/actions/workflows/CI.yml/badge.svg?branch=master)](https://github.com/JuliaCrypto/Ripemd.jl/actions/workflows/CI.yml?query=branch%3Amaster)
[![codecov](https://codecov.io/gh/JuliaCrypto/Ripemd.jl/graph/badge.svg?branch=master)](https://codecov.io/gh/JuliaCrypto/Ripemd.jl)

Pure Julia implementation of the [RIPEMD](https://en.wikipedia.org/wiki/RIPEMD)
hash function. Currently only RIPEMD-160 is implemented.

## Usage

`ripemd160` returns the 20-byte digest as a `Vector{UInt8}`:

```julia
julia> using Ripemd

julia> bytes2hex(ripemd160(b"test"))
"5e52fee47e6b070565f74372468cdc699de89107"
```

The input can be

- any `AbstractVector{UInt8}`, including views, ranges and arrays with
  custom indices,
- a tuple of `UInt8`s,
- an `AbstractString`, whose UTF-8 bytes are hashed,
- an `IO`, which is read until `eof`. For example, to hash a file:

  ```julia
  julia> open(ripemd160, "file.bin")
  ```

### Hashing data incrementally

To hash data that arrives in pieces, create a context, feed it with
`update!` and get the digest with `digest!`. `update!` accepts the same
input types as `ripemd160`, and they can be mixed:

```julia
julia> ctx = RIPEMD160_CTX();

julia> update!(ctx, b"te");

julia> update!(ctx, "st");

julia> bytes2hex(digest!(ctx))
"5e52fee47e6b070565f74372468cdc699de89107"
```

After `digest!` the context cannot be updated anymore. Calling `digest!`
again returns the same digest. To keep hashing after taking an
intermediate digest, `copy` the context first and call `digest!` on the copy.

## Limitations

The implementation only works on little-endian machines. On big-endian
machines the package refuses to load instead of returning wrong hashes.
