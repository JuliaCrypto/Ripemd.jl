using Ripemd
using Test

@testset "digest! marks the context as used" begin
    ctx = RIPEMD160_CTX()
    update!(ctx, b"abc")
    d1 = digest!(ctx)
    @test d1 == ripemd160(b"abc")
    @test ctx.used

    # repeated digest! returns the same digest
    @test digest!(ctx) == d1
    @test digest!(ctx) == d1

    # the returned digest does not alias the context
    d1[1] = ~d1[1]
    @test digest!(ctx) == ripemd160(b"abc")

    # no updates after digest!
    @test_throws ErrorException update!(ctx, b"def")
    @test digest!(ctx) == ripemd160(b"abc")

    # empty context
    ctx = RIPEMD160_CTX()
    @test digest!(ctx) == digest!(ctx) == ripemd160(UInt8[])

    # copy before digest! allows continuing on the copy
    ctx = RIPEMD160_CTX()
    update!(ctx, b"abc")
    ctx2 = copy(ctx)
    @test digest!(ctx) == ripemd160(b"abc")
    @test !ctx2.used
    update!(ctx2, b"def")
    @test digest!(ctx2) == ripemd160(b"abcdef")
end
