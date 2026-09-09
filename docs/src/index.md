# Ripemd.jl

A pure-Julia implementation of the RIPEMD-160 cryptographic hash function.

## Installation

```julia
using Pkg
Pkg.add(url = "https://github.com/USER_OR_ORG/Ripemd.jl")
```

## Quick start

```julia
using Ripemd

# Hash bytes or a string directly
ripemd160("hello world")

# Hex-encoded digest
ripemd160_hex("hello world")

# Hash a file without reading it fully into memory yourself
ripemd160_file("path/to/file.bin")

# Incremental / streaming use
ctx = RIPEMD160_CTX()
update!(ctx, "hello ")
update!(ctx, "world")
digest!(ctx)

# Generic dispatch by algorithm name
digest("ripemd160", "hello world")
```

## API Reference

### Context type

```@docs
RIPEMD160_CTX
```

### Updating and finalizing a hash

```@docs
update!
digest!
```

### One-shot hashing

```@docs
ripemd160
ripemd160_file
ripemd160_hex
digest
```

### Index

```@index
```
