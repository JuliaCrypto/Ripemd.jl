using Ripemd
using Test
using SHA

@testset "SHA interface" begin
    # Ripemd extends SHA's functions, so loading both is not ambiguous
    @test Ripemd.update! === SHA.update!
    @test Ripemd.digest! === SHA.digest!

    ctx = RIPEMD160_CTX()
    update!(ctx, b"abc")
    @test digest!(ctx) == ripemd160(b"abc")

    ctx = SHA256_CTX()
    update!(ctx, b"abc")
    @test digest!(ctx) == sha256(b"abc")
end
