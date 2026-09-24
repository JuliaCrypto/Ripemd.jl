# Batch hashing: hash many independent messages at once.
#
# The code in this file is written so that it runs both on the CPU and inside
# GPU kernels (see ext/RipemdAMDGPUExt.jl): it only uses `getindex` on the
# data container, integer arithmetic, and the pure `transform` function. No
# allocations, no pointers.
#
# Messages are described by a flat byte container `data` and, per message, a
# 0-based byte offset `off` and a length `len`. Two layouts are supported:
#
#   * ragged: `data::AbstractVector{UInt8}` plus `offsets` with N + 1 entries,
#     message i is `data[offsets[i] + 1 : offsets[i + 1]]` (CSR style).
#   * fixed length: `data::AbstractMatrix{UInt8}`, message i is column i.

# number of 64-byte blocks after padding: cld(len + 9, 64)
@inline padded_nblocks(len) = (len + 72) ÷ 64

# little-endian word at 0-based byte offset `o` in `data`
@inline function load_word(data, o)
    @inbounds (UInt32(data[o + 1])       |
               UInt32(data[o + 2]) <<  8 |
               UInt32(data[o + 3]) << 16 |
               UInt32(data[o + 4]) << 24)
end

# Word starting at 0-based byte `b` of the padded message (`b` is a multiple
# of 4, `total` is the padded length). Padding is 0x80, zeros, then the
# 64-bit little-endian bit count in the last 8 bytes. Because
# `total >= len + 9` and both `b` and `total - 8` are multiples of 4, the word
# holding the 0x80 marker never overlaps the bit count.
@inline function padded_word(data, off, len, b, total)
    if b + 4 <= len
        # entirely message bytes
        return load_word(data, off + b)
    elseif b > len
        # entirely padding
        if b == total - 8
            return (UInt64(len) * 8) % UInt32
        elseif b == total - 4
            return ((UInt64(len) * 8) >> 32) % UInt32
        else
            return 0x00000000
        end
    else
        # r ∈ 0:3 message bytes, then the 0x80 marker, then zeros
        r = len - b
        w = UInt32(0x80) << (8 * r)
        @inbounds begin
            r >= 1 && (w |= UInt32(data[off + b + 1]))
            r >= 2 && (w |= UInt32(data[off + b + 2]) << 8)
            r >= 3 && (w |= UInt32(data[off + b + 3]) << 16)
        end
        return w
    end
end

"""
    hash_message(data, off, len) -> NTuple{5, UInt32}

RIPEMD-160 of the `len` bytes of `data` starting after the 0-based byte offset
`off`. Returns the five state words (the digest is their little-endian bytes).
"""
@inline function hash_message(data, off, len)
    nblk = padded_nblocks(len)
    total = nblk * 64
    state = INIT_STATE_TUPLE
    j = 0
    # full blocks entirely inside the message: no padding logic needed
    while j * 64 + 64 <= len
        base = off + j * 64
        w = ntuple(k -> load_word(data, base + 4 * (k - 1)), Val(16))
        state = transform(state, w)
        j += 1
    end
    # remaining one or two blocks with padding
    while j < nblk
        base = j * 64
        w = ntuple(k -> padded_word(data, off, len, base + 4 * (k - 1), total),
                   Val(16))
        state = transform(state, w)
        j += 1
    end
    return state
end

@inline function store_digest!(out, i, s::NTuple{5, UInt32})
    @inbounds for k in 1:5
        v = s[k]
        out[4k - 3, i] = (v      ) % UInt8
        out[4k - 2, i] = (v >>  8) % UInt8
        out[4k - 1, i] = (v >> 16) % UInt8
        out[4k    , i] = (v >> 24) % UInt8
    end
    return nothing
end

"""
    pack_messages(msgs) -> (data::Vector{UInt8}, offsets::Vector{Int})

Concatenate a collection of byte vectors / strings into one flat byte vector
plus a vector of `length(msgs) + 1` 0-based offsets, suitable for
`ripemd160(data, offsets)`.
"""
function pack_messages(msgs)
    n = length(msgs)
    offsets = Vector{Int}(undef, n + 1)
    offsets[1] = 0
    for (i, m) in enumerate(msgs)
        offsets[i + 1] = offsets[i] + sizeof(m)
    end
    data = Vector{UInt8}(undef, offsets[end])
    for (i, m) in enumerate(msgs)
        copyto!(data, offsets[i] + 1, _bytes(m), 1, sizeof(m))
    end
    return data, offsets
end
_bytes(x::AbstractVector{UInt8}) = x
_bytes(x::AbstractString) = codeunits(x)

"""
    ripemd160(data::AbstractVector{UInt8}, offsets::AbstractVector{<:Integer})

Hash `length(offsets) - 1` messages stored back to back in `data`; message `i`
is `data[offsets[i] + 1 : offsets[i + 1]]`. Returns a `20 × N` byte matrix,
column `i` being the digest of message `i`. On the CPU this uses all Julia
threads; with `AMDGPU` loaded and `ROCArray` arguments it runs on the GPU.
"""
function ripemd160(data::AbstractVector{UInt8}, offsets::AbstractVector{<:Integer})
    n = length(offsets) - 1
    n >= 0 || throw(ArgumentError("offsets must have at least one entry"))
    out = Matrix{UInt8}(undef, digest_length(RIPEMD160_CTX), n)
    Threads.@threads for i in 1:n
        @inbounds begin
            off = Int(offsets[i])
            len = Int(offsets[i + 1]) - off
        end
        store_digest!(out, i, hash_message(data, off, len))
    end
    return out
end

"""
    ripemd160(msgs::AbstractMatrix{UInt8})

Hash every column of `msgs` as a separate message. Returns a `20 × size(msgs, 2)`
byte matrix.
"""
function ripemd160(msgs::AbstractMatrix{UInt8})
    len, n = size(msgs)
    out = Matrix{UInt8}(undef, digest_length(RIPEMD160_CTX), n)
    Threads.@threads for i in 1:n
        store_digest!(out, i, hash_message(msgs, (i - 1) * len, len))
    end
    return out
end
