using Ripemd
using Test
using OffsetArrays: OffsetVector

@testset "input types" begin
    data = UInt8[UInt8((31 * i + 7) % 256) for i in 1:1000]
    ref = ripemd160(data)

    @testset "AbstractVector{UInt8}" begin
        padded = vcat(UInt8[0xff, 0xfe], data, UInt8[0xfd])
        @test ripemd160(view(padded, 3:1002)) == ref           # SubArray
        @test ripemd160(@view data[1:2:end]) == ripemd160(data[1:2:end]) # strided view
        @test ripemd160(reinterpret(UInt8, reinterpret(UInt32, data))) == ref
        @test ripemd160(0x00:0xff) == ripemd160(collect(0x00:0xff)) # range
        @test ripemd160(codeunits("abc")) == ripemd160(b"abc")
    end

    @testset "offset indices (firstindex = $(o + 1))" for o in (-1000, -11, -1, 0, 5)
        @test ripemd160(OffsetVector(data, o)) == ref
        # partial blocks, so that copying starts at a non-zero source offset
        ctx = RIPEMD160_CTX()
        update!(ctx, OffsetVector(data[1:30], o))
        update!(ctx, OffsetVector(data[31:end], o))
        @test digest!(ctx) == ref
    end

    @testset "tuples" begin
        @test ripemd160(Tuple(data)) == ref
        @test ripemd160(()) == ripemd160(UInt8[])
    end

    @testset "strings" begin
        s = "Ripemd160 – ünïcödé"
        @test ripemd160(s) == ripemd160(Vector{UInt8}(codeunits(s)))
        @test ripemd160(SubString("xx" * s, 3)) == ripemd160(s)
    end

    @testset "IO" begin
        @test ripemd160(IOBuffer(data)) == ref
        @test ripemd160(IOBuffer(UInt8[])) == ripemd160(UInt8[])
        ctx = RIPEMD160_CTX()
        update!(ctx, IOBuffer(data); chunksize = 7)   # chunks not aligned to blocks
        @test digest!(ctx) == ref
        # invalid chunk sizes are rejected instead of looping forever
        @test_throws ArgumentError update!(RIPEMD160_CTX(), IOBuffer(data); chunksize = 0)
        @test_throws ArgumentError update!(RIPEMD160_CTX(), IOBuffer(data); chunksize = -1)
        # a used context rejects IO input without consuming it, also if empty
        ctx = RIPEMD160_CTX(); digest!(ctx)
        io = IOBuffer(data)
        @test_throws ErrorException update!(ctx, io)
        @test position(io) == 0
        @test_throws ErrorException update!(ctx, IOBuffer(UInt8[]))
        mktemp() do path, io
            write(io, data); close(io)
            @test open(ripemd160, path) == ref
        end
    end

    @testset "mixed update! calls" begin
        ctx = RIPEMD160_CTX()
        update!(ctx, view(data, 1:100))
        update!(ctx, Tuple(data[101:200]))
        update!(ctx, IOBuffer(data[201:900]))
        update!(ctx, String(data[901:1000]))
        @test digest!(ctx) == ref
    end
end
