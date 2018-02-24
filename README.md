# Ripemd

[![Build Status](https://travis-ci.org/gdkrmr/Ripemd.jl.svg?branch=master)](https://travis-ci.org/gdkrmr/Ripemd.jl)
[![codecov.io](http://codecov.io/github/gdkrmr/Ripemd.jl/coverage.svg?branch=master)](http://codecov.io/github/gdkrmr/Ripemd.jl?branch=master)

Usage is very simple:
```julia
julia> using Ripemd

julia> bytes2hex(ripemd160(b"test"))
"5e52fee47e6b070565f74372468cdc699de89107"
```

Currently only Ripemd160 is implemented and convenience functions are missing.

Should work on julia 0.7, tests are failing because they depend on `Nettle.jl`
which currently is not available for julia 0.7 yet.
