const ByteData = Union{AbstractVector{UInt8}, NTuple{N, UInt8} where N}

# Copy n bytes from data, starting after the first soff bytes, into
# buf[doff+1:doff+n].
@inline function copybytes!(buf::Vector{UInt8}, doff, data::AbstractVector{UInt8}, soff, n)
    # the offsets are unsigned; mixing them with a negative firstindex (e.g.
    # of an OffsetArray) would wrap around, so do the index arithmetic in Int
    copyto!(buf, Int(doff) + 1, data, firstindex(data) + Int(soff), Int(n))
end
@inline function copybytes!(buf::Vector{UInt8}, doff, data::Tuple, soff, n)
    # the generic copyto! for tuples iterates from the start every time
    @inbounds for i in 1:n
        buf[doff + i] = data[soff + i]
    end
    return buf
end

"""
    update!(ctx::RIPEMD160_CTX, data)

Feed `data` into the hash context `ctx`. `data` can be any
`AbstractVector{UInt8}`, a tuple of `UInt8`s, an `AbstractString` (its UTF-8
bytes are hashed) or an `IO` (read until `eof`).
"""
function update!(ctx::T, data::ByteData) where {T <: RIPEMD160_CTX}
    UIntXXX = typeof(ctx.count)
    ctx.used && error("Cannot update CTX after `digest!` has been called on it")

    len = convert(UIntXXX, length(data))
    data_idx = convert(UIntXXX, 0)
    usedspace = ctx.count % bytes_per_block(T)

    while len - data_idx + usedspace >= bytes_per_block(T)
        # fill up the rest of the (possibly partially filled) buffer
        n = bytes_per_block(T) - usedspace
        copybytes!(ctx.buffer, usedspace, data, data_idx, n)

        transform!(ctx)

        ctx.count += n
        data_idx += n
        usedspace = convert(UIntXXX, 0)
    end

    if len > data_idx
        copybytes!(ctx.buffer, usedspace, data, data_idx, len - data_idx)
        ctx.count += len - data_idx
    end
    return nothing
end

update!(ctx::RIPEMD160_CTX, str::AbstractString) = update!(ctx, codeunits(String(str)))

function update!(ctx::RIPEMD160_CTX, io::IO; chunksize::Integer = 64 * 1024)
    # check before reading, so that nothing is consumed from io on error
    ctx.used && error("Cannot update CTX after `digest!` has been called on it")
    chunksize > 0 || throw(ArgumentError("chunksize must be positive, got $chunksize"))
    buf = Vector{UInt8}(undef, chunksize)
    while !eof(io)
        n = readbytes!(io, buf)
        update!(ctx, view(buf, 1:n))
    end
    return nothing
end

function pad_remainder!(ctx::T) where {T <: RIPEMD160_CTX}

    @inbounds begin

        usedspace = ctx.count % bytes_per_block(T)

        if usedspace > 0
            usedspace += 1
            ctx.buffer[usedspace] = 0x80

            # do we have space for a UInt64?
            if usedspace <= bytes_per_block(T) - sizeof(ctx.count)
                # space for UInt64 so fill with 0x0 except the last UInt64
                for i = (usedspace + 1):(length(ctx.buffer) - sizeof(ctx.count))
                    ctx.buffer[i] = 0x0
                end
            else
                # no space for UInt64 fill out everything, transform and fill with
                # 0x0
                for i = (usedspace + 1):length(ctx.buffer)
                    ctx.buffer[i] = 0x0
                end
                transform!(ctx)
                for i = 1:bytes_per_block(T)
                    ctx.buffer[i] = 0x0
                end
            end
        else # usedspace == 0
            ctx.buffer[1] = 0x80
            for i = 2:bytes_per_block(T)
                ctx.buffer[i] = 0x0
            end
        end
    end
    return nothing
end

# Pad the message and process the final block(s); afterwards ctx.state holds
# the digest.
function finalize!(ctx::T) where {T <: RIPEMD160_CTX}
    pad_remainder!(ctx)

    # bitcount_idx = div(words_per_block(T), sizeof(ctx.count)) + 1
    buffer = ctx.buffer
    GC.@preserve buffer begin
        pbuf = Ptr{typeof(ctx.count)}(pointer(buffer))
        unsafe_store!(pbuf, UInt64(ctx.count * 8), 8)
    end

    transform!(ctx)
    ctx.used = true
    return nothing
end

"""
    digest!(ctx::RIPEMD160_CTX)

Finalize the hash computation and return the 20-byte digest. After this, `ctx`
cannot be updated anymore; calling `digest!` again returns the same digest.
"""
function digest!(ctx::T) where {T <: RIPEMD160_CTX}
    ctx.used || finalize!(ctx)
    # indexing copies, so the result does not alias ctx.state
    return reinterpret(UInt8, ctx.state)[1:digest_length(T)]
end
