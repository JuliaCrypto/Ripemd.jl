__precompile__()

module Ripemd

export ripemd160, update!, digest!, RIPEMD160_CTX

include("consts.jl")
include("types.jl")
include("interface.jl")
include("transform.jl")

if VERSION < v"0.7.0-DEV.3213"
    codeunits(x) = convert(Array{UInt8}, x)
end

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
