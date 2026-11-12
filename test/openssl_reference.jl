using OpenSSL_jll: libcrypto

# Reference implementation: RIPEMD160() from OpenSSL's libcrypto.
function openssl_ripemd160(x::AbstractVector{UInt8})
    data = Vector{UInt8}(x)
    md = zeros(UInt8, 20)
    ccall((:RIPEMD160, libcrypto), Ptr{UInt8},
          (Ptr{UInt8}, Csize_t, Ptr{UInt8}),
          data, length(data), md)
    return bytes2hex(md)
end

openssl_ripemd160(x::AbstractString) = openssl_ripemd160(codeunits(x))
openssl_ripemd160(x::NTuple{N, UInt8}) where N = openssl_ripemd160(collect(x))
