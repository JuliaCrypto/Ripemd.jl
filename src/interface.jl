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
