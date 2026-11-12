using Ripemd
using Test

@testset "update! in chunks" begin
    data = UInt8[UInt8((7 * i + 3) % 256) for i in 1:300]
    for n in (0, 1, 55, 56, 63, 64, 65, 127, 128, 129, 300)
        x = data[1:n]
        ref = ripemd160(x)
        # every split point into two chunks
        for k in 0:n
            ctx = RIPEMD160_CTX()
            update!(ctx, x[1:k])
            update!(ctx, x[k+1:end])
            @test digest!(ctx) == ref
        end
        # fixed chunk sizes, including ones that never align with the block
        for chunk in (1, 3, 7, 63, 64, 65)
            ctx = RIPEMD160_CTX()
            for i in 1:chunk:n
                update!(ctx, x[i:min(i + chunk - 1, n)])
            end
            @test digest!(ctx) == ref
        end
    end
end
