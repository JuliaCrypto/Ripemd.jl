# Ripemd.jl

[![CI](https://github.com/JuliaCrypto/Ripemd.jl/actions/workflows/CI.yml/badge.svg?branch=master)](https://github.com/JuliaCrypto/Ripemd.jl/actions/workflows/CI.yml?query=branch%3Amaster)
[![codecov](https://codecov.io/gh/JuliaCrypto/Ripemd.jl/graph/badge.svg?branch=master)](https://codecov.io/gh/JuliaCrypto/Ripemd.jl)

Pure Julia implementation of the [Ripemd](https://en.wikipedia.org/wiki/RIPEMD) hashing algorithm.
Currently only Ripemd160 is implemented and convenience functions are missing.

Usage is very simple:
```julia
julia> using Ripemd

julia> bytes2hex(ripemd160(b"test"))
"5e52fee47e6b070565f74372468cdc699de89107"
```
