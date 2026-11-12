module Ripemd

# Extend the generic hashing interface of the SHA stdlib instead of defining
# separate functions, so that `using SHA, Ripemd` does not make `update!` and
# `digest!` ambiguous.
import SHA: update!, digest!

export ripemd160, update!, digest!, RIPEMD160_CTX

include("consts.jl")
include("types.jl")
include("interface.jl")
include("transform.jl")

"""
    ripemd160(data)

Compute the RIPEMD-160 hash of `data` and return it as a 20-byte
`Vector{UInt8}`. `data` can be any `AbstractVector{UInt8}`, a tuple of
`UInt8`s, an `AbstractString` (its UTF-8 bytes are hashed) or an `IO` (read
until `eof`).
"""
function ripemd160(data::Union{ByteData, AbstractString, IO})
    ctx = RIPEMD160_CTX()
    update!(ctx, data)
    return digest!(ctx)
end

end # module Ripemd
