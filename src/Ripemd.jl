__precompile__()

module Ripemd

export ripemd160, update!, digest!

include("consts.jl")
include("types.jl")
include("interface.jl")
include("transform.jl")

function ripemd160(data::T) where T<:Union{Array{UInt8,1},NTuple{N,UInt8} where N}
    ctx = RIPEMD160_CTX()
    update!(ctx, data)
    return digest!(ctx)
end

end # module Ripemd
