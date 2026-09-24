# AMDGPU backend: every work-item hashes one message.
module RipemdAMDGPUExt

using Ripemd
using Ripemd: hash_message, store_digest!, digest_length, RIPEMD160_CTX
using AMDGPU
using AMDGPU: ROCDeviceArray

const GROUPSIZE = 256

# One 4-byte load with alignment 1 instead of four byte loads. Global memory
# on AMD GPUs supports unaligned dword loads, LLVM emits a single
# `global_load_dword`; this roughly halves the register pressure of the kernel.
@inline function Ripemd.load_word(data::ROCDeviceArray{UInt8, N, A}, o) where {N, A}
    p = reinterpret(Core.LLVMPtr{UInt32, A}, pointer(data)) + o
    return unsafe_load(p, 1, Val(1))
end

# ragged layout: message i is data[offsets[i]+1 : offsets[i+1]]
function ripemd160_ragged_kernel!(out, data, offsets, n)
    i = (workgroupIdx().x - 1) * workgroupDim().x + workitemIdx().x
    if i <= n
        @inbounds begin
            off = Int(offsets[i])
            len = Int(offsets[i + 1]) - off
        end
        store_digest!(out, i, hash_message(data, off, len))
    end
    return nothing
end

# fixed-length layout: message i is column i of msgs (linear indexed)
function ripemd160_fixed_kernel!(out, msgs, len, n)
    i = (workgroupIdx().x - 1) * workgroupDim().x + workitemIdx().x
    if i <= n
        store_digest!(out, i, hash_message(msgs, (i - 1) * len, len))
    end
    return nothing
end

"""
    ripemd160(data::ROCVector{UInt8}, offsets::ROCVector{<:Integer})

GPU version of the ragged batch API: message `i` is
`data[offsets[i] + 1 : offsets[i + 1]]`, one work-item per message. Returns a
`20 × N` `ROCMatrix{UInt8}`. The launch is asynchronous; `Array(result)` or
`AMDGPU.synchronize()` waits for it.
"""
function Ripemd.ripemd160(data::ROCVector{UInt8}, offsets::ROCVector{<:Integer})
    n = length(offsets) - 1
    n >= 0 || throw(ArgumentError("offsets must have at least one entry"))
    out = ROCArray{UInt8}(undef, digest_length(RIPEMD160_CTX), n)
    n == 0 && return out
    @roc groupsize=GROUPSIZE gridsize=cld(n, GROUPSIZE) ripemd160_ragged_kernel!(
        out, data, offsets, n)
    return out
end

"""
    ripemd160(msgs::ROCMatrix{UInt8})

GPU version of the fixed-length batch API: every column of `msgs` is one
message, one work-item per message. Returns a `20 × size(msgs, 2)`
`ROCMatrix{UInt8}`.
"""
function Ripemd.ripemd160(msgs::ROCMatrix{UInt8})
    len, n = size(msgs)
    out = ROCArray{UInt8}(undef, digest_length(RIPEMD160_CTX), n)
    n == 0 && return out
    @roc groupsize=GROUPSIZE gridsize=cld(n, GROUPSIZE) ripemd160_fixed_kernel!(
        out, msgs, len, n)
    return out
end

"""
    ripemd160(msg::ROCVector{UInt8})

Hash a single message that lives on the GPU. Returns the 20-byte digest as a
`ROCVector{UInt8}`. This runs on one work-item and is only useful to avoid a
transfer; for throughput hash many messages at once.
"""
function Ripemd.ripemd160(msg::ROCVector{UInt8})
    return vec(Ripemd.ripemd160(reshape(msg, length(msg), 1)))
end

end # module
