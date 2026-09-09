module Ripemd

export ripemd160, update!, digest!, digest, RIPEMD160_CTX, bytes2hex, ripemd160_file, ripemd160_hex

const INIT_STATE = UInt32[
    0x67452301,
    0xEFCDAB89,
    0x98BADCFE,
    0x10325476,
    0xC3D2E1F0
]

const K0  = UInt32(0x00000000)
const K1  = UInt32(0x5A827999)
const K2  = UInt32(0x6ED9EBA1)
const K3  = UInt32(0x8F1BBCDC)
const K4  = UInt32(0xA953FD4E)

const KK0 = UInt32(0x50A28BE6)
const KK1 = UInt32(0x5C4DD124)
const KK2 = UInt32(0x6D703EF3)
const KK3 = UInt32(0x7A6D76E9)
const KK4 = UInt32(0x00000000)

@inline ROTL32(x::UInt32, n::UInt8) =
    (x << n) | (x >> (UInt8(32) - n))

# Read a little-endian UInt32 word out of a raw byte buffer, regardless of
# host byte order. `ltoh` is a no-op on little-endian hosts and a `bswap`
# on big-endian hosts, so this is what makes transform! endian-correct.
@inline load32_le(buf::Ptr{UInt32}, i) = ltoh(unsafe_load(buf, i))

@inline F0(x, y, z) = x ⊻ y ⊻ z
@inline F1(x, y, z) = (x & y) | (~x & z)
@inline F2(x, y, z) = (x | ~y) ⊻ z
@inline F3(x, y, z) = (x & z) | (y & ~z)
@inline F4(x, y, z) = x ⊻ (y | ~z)

const left_p = (
     1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 15, 16,
     8,  5, 14,  2, 11,  7, 16,  4, 13,  1, 10,  6,  3, 15, 12,  9,
     4, 11, 15,  5, 10, 16,  9,  2,  3,  8,  1,  7, 14, 12,  6, 13,
     2, 10, 12, 11,  1,  9, 13,  5, 14,  4,  8, 16, 15,  6,  7,  3,
     5,  1,  6, 10,  8, 13,  3, 11, 15,  2,  4,  9, 12,  7, 16, 14
)

const left_q = (
    11, 14, 15, 12,  5,  8,  7,  9, 11, 13, 14, 15,  6,  7,  9,  8,
     7,  6,  8, 13, 11,  9,  7, 15,  7, 12, 15,  9, 11,  7, 13, 12,
    11, 13,  6,  7, 14,  9, 13, 15, 14,  8, 13,  6,  5, 12,  7,  5,
    11, 12, 14, 15, 14, 15,  9,  8,  9, 14,  5,  6,  8,  6,  5, 12,
     9, 15,  5, 11,  6,  8, 13, 12,  5, 12, 13, 14, 11,  8,  5,  6
)

const right_p = (
     6, 15,  8,  1, 10,  3, 12,  5, 14,  7, 16,  9,  2, 11,  4, 13,
     7, 12,  4,  8,  1, 14,  6, 11, 15, 16,  9, 13,  5, 10,  2,  3,
    16,  6,  2,  4,  8, 15,  7, 10, 12,  9, 13,  3, 11,  1,  5, 14,
     9,  7,  5,  2,  4, 12, 16,  1,  6, 13,  3, 14, 10,  8, 11, 15,
    13, 16, 11,  5,  2,  6,  9,  8,  7,  3, 14, 15,  1,  4, 10, 12
)

const right_q = (
     8,  9,  9, 11, 13, 15, 15,  5,  7,  7,  8, 11, 14, 14, 12,  6,
     9, 13, 15,  7, 12,  8,  9, 11,  7,  7, 12,  7,  6, 15, 13, 11,
     9,  7, 15, 11,  8,  6,  6, 14, 12, 13,  5, 14, 13, 13,  7,  5,
    15,  5,  8, 11, 14, 14,  6, 14,  6,  9, 12,  9, 12,  5, 15,  8,
     8,  5, 12,  9, 12,  5, 14,  6,  8, 13,  6,  5, 15, 13, 11, 11
)

macro L(i)
    ww = (:a, :b, :c, :d, :e)
    a = ww[((81 - i) % 5) + 1]
    b = ww[((82 - i) % 5) + 1]
    c = ww[((83 - i) % 5) + 1]
    d = ww[((84 - i) % 5) + 1]
    e = ww[((85 - i) % 5) + 1]
    f = Symbol("F", div(i - 1, 16))
    k = Symbol("K", div(i - 1, 16))
    r = left_p[i]
    s = left_q[i]
    esc(quote
        t = $a + $f($b, $c, $d) + $k + load32_le(buf, $r)
        $a = ROTL32(UInt32(t), UInt8($s)) + $e
        $c = ROTL32($c, UInt8(10))
    end)
end

macro R(i)
    ww = (:a, :b, :c, :d, :e)
    a = ww[((81 - i) % 5) + 1]
    b = ww[((82 - i) % 5) + 1]
    c = ww[((83 - i) % 5) + 1]
    d = ww[((84 - i) % 5) + 1]
    e = ww[((85 - i) % 5) + 1]
    f = Symbol("F", 4 - div(i - 1, 16))
    k = Symbol("KK", div(i - 1, 16))
    r = right_p[i]
    s = right_q[i]
    esc(quote
        t = $a + $f($b, $c, $d) + $k + load32_le(buf, $r)
        $a = ROTL32(UInt32(t), UInt8($s)) + $e
        $c = ROTL32($c, UInt8(10))
    end)
end

abstract type RIPEMD_CTX end

mutable struct RIPEMD160_CTX <: RIPEMD_CTX
    state::Vector{UInt32}
    count::UInt64
    buffer::Vector{UInt8}
end

# These are for external uses of the struct, to define the parameters of RIPEMD160 variant of RIPEMD
bytes_per_block(::Type{RIPEMD160_CTX}) = 64
words_per_block(::Type{RIPEMD160_CTX}) = 16
state_type(::Type{RIPEMD160_CTX}) = UInt32
digest_length(::Type{RIPEMD160_CTX}) = 20

RIPEMD160_CTX() = RIPEMD160_CTX(copy(INIT_STATE), UInt64(0), zeros(UInt8, 64))

"""
    update!(ctx::RIPEMD160_CTX, data::Union{AbstractVector{UInt8}, NTuple{N,UInt8} where N})

Update the RIPEMD160 context `ctx` with the given `data`. The data can be a vector of bytes or a tuple of bytes.

Arguments
---------
ctx : RIPEMD160_CTX
    The RIPEMD160 context to update.
data : Union{AbstractVector{UInt8}, NTuple{N,UInt8} where N}
    The input data to update the context with.
Returns
-------
Nothing. The context `ctx` is updated in place.
"""
function update!(ctx::RIPEMD160_CTX, data::Union{AbstractVector{UInt8}, NTuple{N,UInt8} where N})
    len = length(data)
    pos = 1

    used = Int(ctx.count & 0x3f)

    if used != 0
        n = min(64 - used, len)
        copyto!(ctx.buffer, used + 1, data, pos, n)
        ctx.count += UInt64(n)
        pos += n

        if n < 64 - used
            return nothing
        end

        transform!(ctx)
        used = 0
    end

    while pos + 63 <= len
        copyto!(ctx.buffer, 1, data, pos, 64)
        transform!(ctx)
        ctx.count += UInt64(64)
        pos += 64
    end

    if pos <= len
        n = len - pos + 1
        copyto!(ctx.buffer, 1, data, pos, n)
        ctx.count += UInt64(n)
    end

    nothing
end

# --- Convenience methods -------------------------------------------------

"""
    update!(ctx::RIPEMD160_CTX, data::AbstractString)

Update the RIPEMD160 context `ctx` with the given string `data`. The string is converted to bytes internally.

Arguments
---------
ctx : RIPEMD160_CTX
    The RIPEMD160 context to update.
data : AbstractString
    The input string to update the context with.
Returns
-------
Nothing. The context `ctx` is updated in place.
"""
update!(ctx::RIPEMD160_CTX, data::AbstractString) =
    update!(ctx, Vector{UInt8}(codeunits(data)))

"""
    update!(ctx::RIPEMD160_CTX, io::IO; chunk_size::Integer = 4096)

Update the RIPEMD160 context `ctx` with data read from the given IO stream `io`. The data is read in chunks of size `chunk_size`.

Arguments
---------
ctx : RIPEMD160_CTX
    The RIPEMD160 context to update.
io : IO
    The input IO stream to read data from. This can be a file, stdin, etc.
chunk_size : Integer, optional
    The size of the chunks to read from the IO stream (default is 4096).
Returns
-------
Nothing. The context `ctx` is updated in place.
"""
function update!(ctx::RIPEMD160_CTX, io::IO; chunk_size::Integer = 4096)
    buf = Vector{UInt8}(undef, chunk_size)
    while !eof(io)
        n = readbytes!(io, buf)
        update!(ctx, view(buf, 1:n))
    end
    nothing
end

"""
    ripemd160(io::IO)

Hash directly from an IO stream (e.g. `open(io -> ripemd160(io), path)`),
mirroring the AbstractVector{UInt8}/AbstractString methods below.
"""
function ripemd160(io::IO)
    ctx = RIPEMD160_CTX()
    update!(ctx, io)
    digest!(ctx)
end

"""
    ripemd160_file(path::AbstractString)

Hash the contents of the file at the given `path` using the RIPEMD160 hash function.
Arguments
---------
path : AbstractString
    The path to the file to hash.
Returns
-------
The RIPEMD160 hash of the file's contents as a vector of bytes.
"""
function ripemd160_file(path::AbstractString)
    open(io -> ripemd160(io), path, "r")
end

"""
    ripemd160_hex(data)

Return the digest as a lowercase hex string, if the caller wants it in that
form, in order to display or compare a string rather than the raw bytes.
"""
ripemd160_hex(data) = bytes2hex(ripemd160(data))

# Fallback bytes2hex in case an older Julia version doesn't already
# export/define it in Base.
if !isdefined(Base, :bytes2hex)
    """
        bytes2hex(bytes::AbstractVector{UInt8})

    Fallback implementation of `Base.bytes2hex` for Julia versions where it
    isn't already defined, returning the lowercase hex encoding of `bytes`.
    """
    function bytes2hex(bytes::AbstractVector{UInt8})
        io = IOBuffer()
        for b in bytes
            print(io, string(b, base = 16, pad = 2))
        end
        String(take!(io))
    end
end

# --------------------------------------------------------------------------

function pad_remainder!(ctx::RIPEMD160_CTX)
    used = Int(ctx.count & 0x3f)
    ctx.buffer[used + 1] = 0x80

    if used < 56
        fill!(view(ctx.buffer, used + 2:56), 0x00)
    else
        fill!(view(ctx.buffer, used + 2:64), 0x00)
        transform!(ctx)
        fill!(ctx.buffer, 0x00)
    end

    nothing
end

"""
    digest!(ctx::RIPEMD160_CTX)

Finalize the RIPEMD160 hash computation and return the digest as a vector of bytes.
Arguments
---------
ctx : RIPEMD160_CTX
    The context containing the current state of the hash computation.
Returns
-------
A vector of bytes representing the RIPEMD160 hash.
"""
function digest!(ctx::RIPEMD160_CTX)
    pad_remainder!(ctx)

    # RIPEMD-160 stores the 64-bit bit-length little-endian; `htol` makes
    # this correct on big-endian hosts too (no-op on little-endian ones).
    bits = htol(ctx.count << 3)

    p = Ptr{UInt64}(pointer(ctx.buffer, 57))
    unsafe_store!(p, bits)

    transform!(ctx)

    # The five UInt32 state words must be emitted as little-endian bytes
    # regardless of host order, so convert each word with `htol` before
    # reinterpreting it as raw bytes.
    le_state = map(htol, ctx.state)
    reinterpret(UInt8, le_state)[1:20] # we need [1:20] to make a copy here
end

"""
Should work correctly on both little-endian and big-endian systems: word loads in
transform! go through `load32_le` (uses `ltoh`), the bit-length field is
written via `htol`, and the final digest bytes are produced from `htol`-ed
state words -- so all raw-pointer traffic is explicitly normalized to the
little-endian byte order RIPEMD-160 specifies, rather than relying on the
host's native order.
"""
function transform!(ctx::RIPEMD160_CTX)
    # NB: @inbounds works on assumption ctx.buffer is always exactly 64 bytes in size
    @inbounds begin
        buf = Ptr{UInt32}(pointer(ctx.buffer))

        a, b, c, d, e = ctx.state

        @L(1);  @L(2);  @L(3);  @L(4);  @L(5);  @L(6);  @L(7);  @L(8)
        @L(9);  @L(10); @L(11); @L(12); @L(13); @L(14); @L(15); @L(16)
        @L(17); @L(18); @L(19); @L(20); @L(21); @L(22); @L(23); @L(24)
        @L(25); @L(26); @L(27); @L(28); @L(29); @L(30); @L(31); @L(32)
        @L(33); @L(34); @L(35); @L(36); @L(37); @L(38); @L(39); @L(40)
        @L(41); @L(42); @L(43); @L(44); @L(45); @L(46); @L(47); @L(48)
        @L(49); @L(50); @L(51); @L(52); @L(53); @L(54); @L(55); @L(56)
        @L(57); @L(58); @L(59); @L(60); @L(61); @L(62); @L(63); @L(64)
        @L(65); @L(66); @L(67); @L(68); @L(69); @L(70); @L(71); @L(72)
        @L(73); @L(74); @L(75); @L(76); @L(77); @L(78); @L(79); @L(80)

        aa, bb, cc, dd, ee = a, b, c, d, e

        a, b, c, d, e = ctx.state

        @R(1);  @R(2);  @R(3);  @R(4);  @R(5);  @R(6);  @R(7);  @R(8)
        @R(9);  @R(10); @R(11); @R(12); @R(13); @R(14); @R(15); @R(16)
        @R(17); @R(18); @R(19); @R(20); @R(21); @R(22); @R(23); @R(24)
        @R(25); @R(26); @R(27); @R(28); @R(29); @R(30); @R(31); @R(32)
        @R(33); @R(34); @R(35); @R(36); @R(37); @R(38); @R(39); @R(40)
        @R(41); @R(42); @R(43); @R(44); @R(45); @R(46); @R(47); @R(48)
        @R(49); @R(50); @R(51); @R(52); @R(53); @R(54); @R(55); @R(56)
        @R(57); @R(58); @R(59); @R(60); @R(61); @R(62); @R(63); @R(64)
        @R(65); @R(66); @R(67); @R(68); @R(69); @R(70); @R(71); @R(72)
        @R(73); @R(74); @R(75); @R(76); @R(77); @R(78); @R(79); @R(80)

        s1 = ctx.state[1]
        ctx.state[1] = ctx.state[2] + d + cc
        ctx.state[2] = ctx.state[3] + e + dd
        ctx.state[3] = ctx.state[4] + a + ee
        ctx.state[4] = ctx.state[5] + b + aa
        ctx.state[5] = s1 + c + bb
    end

    nothing
end

"""
    ripemd160(data::Union{AbstractVector{UInt8}, NTuple{N,UInt8} where N})

Compute the RIPEMD160 hash of the given data.
Arguments
---------
data : Union{AbstractVector{UInt8}, NTuple{N,UInt8} where N}
    The input data to hash.
Returns
-------
A vector of bytes representing the RIPEMD160 hash of the input data.
"""
function ripemd160(data::Union{AbstractVector{UInt8}, NTuple{N,UInt8} where N})
    ctx = RIPEMD160_CTX()
    update!(ctx, data)
    digest!(ctx)
end

"""
    ripemd160(str::AbstractString)

Compute the RIPEMD160 hash of the given string.
Arguments
---------
str : AbstractString
    The input string to hash.
Returns
-------
A vector of bytes representing the RIPEMD160 hash of the input string.
"""
ripemd160(str::AbstractString) =
    ripemd160(Vector{UInt8}(codeunits(str)))

"""
    digest(name::AbstractString, data)

Compute the hash of the given data using the specified digest algorithm.
Arguments
---------
name : AbstractString
    The name of the digest algorithm (e.g., "ripemd160").
data : Union{AbstractVector{UInt8}, NTuple{N,UInt8} where N}
    The input data to hash.
Returns
-------
A vector of bytes representing the hash of the input data.
"""
function digest(name::AbstractString, data)
    lname = lowercase(name)

    if lname == "ripemd160" ||
       lname == "rmd160" ||
       lname == "ripemd-160"
        return ripemd160(data)
    end

    throw(ArgumentError("unsupported digest: $name"))
end

end # module or file end
