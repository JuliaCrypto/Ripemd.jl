const ByteData = Union{AbstractVector{UInt8}, NTuple{N, UInt8} where N}

# Copy n bytes from data, starting after the first soff bytes, into
# buf[doff+1:doff+n].
@inline function copybytes!(buf::Vector{UInt8}, doff, data::AbstractVector{UInt8}, soff, n)
    copyto!(buf, doff + 1, data, firstindex(data) + soff, n)
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

function digest!(ctx::T) where {T <: RIPEMD160_CTX}
    pad_remainder!(ctx)

    # bitcount_idx = div(words_per_block(T), sizeof(ctx.count)) + 1
    pbuf = Ptr{typeof(ctx.count)}(pointer(ctx.buffer))
    unsafe_store!(pbuf, UInt64(ctx.count * 8), 8)

    transform!(ctx)

    # TODO: is this safe for 0.7? the [1:end] should make a copy and get around
    # the lazy reinterpret.
    return reinterpret(UInt8, ctx.state)[1:digest_length(T)]
end
