module Ripemd

export ripemd160, update!, digest!, RIPEMD160_CTX

include("consts.jl")
include("types.jl")
include("interface.jl")
include("transform.jl")

function ripemd160(data::T) where T <: Union{DenseArray{UInt8, 1},
                                             NTuple{N, UInt8} where N}
    ctx = RIPEMD160_CTX()
    update!(ctx, data)
    return digest!(ctx)
end

ripemd160(str::AbstractString) = ripemd160(Vector{UInt8}(codeunits(str)))

end # module Ripemd
