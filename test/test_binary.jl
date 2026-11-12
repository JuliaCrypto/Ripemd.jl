using Ripemd
using Test

@isdefined(openssl_ripemd160) || include(joinpath(@__DIR__, "openssl_reference.jl"))

# Small deterministic byte generator (xorshift64), so the test data does not
# depend on the Random stdlib's stream, which may change between versions.
function pseudorandom_bytes(n::Integer, seed::UInt64)
    x = seed
    out = Vector{UInt8}(undef, n)
    for i in 1:n
        x ⊻= x << 13; x ⊻= x >> 7; x ⊻= x << 17
        out[i] = x % UInt8
    end
    return out
end

ref(x) = openssl_ripemd160(x)
hash_hex(x) = bytes2hex(ripemd160(x))

@testset "binary data vs openssl" begin
    @testset "every single byte value" begin
        for b in 0x00:0xff
            @test hash_hex([b]) == ref([b])
        end
    end

    @testset "pseudorandom bytes, lengths 0:300" begin
        for n in 0:300
            x = pseudorandom_bytes(n, UInt64(0x9e3779b97f4a7c15) + n)
            @test hash_hex(x) == ref(x)
        end
    end

    @testset "special byte patterns" begin
        for n in (1, 55, 56, 63, 64, 65, 1000)
            for b in (0x00, 0x80, 0xff)
                x = fill(b, n)
                @test hash_hex(x) == ref(x)
            end
        end
        # NUL bytes, printf metacharacters and invalid UTF-8
        x = UInt8[0x00, 0x25, 0x73, 0x5c, 0x6e, 0x00, 0xc3, 0x28, 0xff, 0xfe, 0x00]
        @test hash_hex(x) == ref(x)
    end

    @testset "1 MiB of pseudorandom bytes" begin
        x = pseudorandom_bytes(2^20, UInt64(42))
        @test hash_hex(x) == ref(x)
    end
end
