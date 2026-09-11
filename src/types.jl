
""" Abstract type for RIPEMD hash function contexts. Currently there is only RIPEMD160_CTX. """
abstract type RIPEMD_CTX end

"""
    RIPEMD160_CTX

Mutable struct representing the context for the RIPEMD160 hash function.
Contains the internal `state`, the `count` of processed bytes, and a `buffer` for input data.
"""
mutable struct RIPEMD160_CTX <: RIPEMD_CTX
    state  :: Array{UInt32, 1} # length 5
    count  :: UInt64           # how many bytes we already ingested
    buffer :: Array{UInt8, 1}  # message is copied here, read as UInt32 in
                               # transform!
end

""" Length of the buffer for RIPEMD160_CTX blocks. """
bytes_per_block(::Type{RIPEMD160_CTX}) = 64

""" Number of 32-bit words in a RIPEMD160_CTX block. """
words_per_block(::Type{RIPEMD160_CTX}) = 16

""" Type of the internal state words for RIPEMD160. """
state_type(::Type{RIPEMD160_CTX}) = UInt32

""" Length of the final digest for RIPEMD160_CTX in bytes. """
digest_length(::Type{RIPEMD160_CTX}) = 20

""" Constructor for RIPEMD160_CTX.

Returns a new instance of `RIPEMD160_CTX` with the initial state, zero count, and an empty buffer.
"""
function RIPEMD160_CTX()
    RIPEMD160_CTX(copy(INIT_STATE), 0 , zeros(UInt8, bytes_per_block(RIPEMD160_CTX)))
end
