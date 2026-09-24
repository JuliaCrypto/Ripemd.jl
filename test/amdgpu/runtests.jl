# GPU backend tests. Run with
#   julia --project=test/amdgpu test/amdgpu/runtests.jl
# (needs AMDGPU.jl and a working ROCm installation)

using Ripemd
using AMDGPU
using Test
using Random

AMDGPU.functional() || error("AMDGPU is not functional on this machine")

streaming(msgs) = hcat([ripemd160(m) for m in msgs]...)

@testset "AMDGPU: extension loaded" begin
    @test Base.get_extension(Ripemd, :RipemdAMDGPUExt) !== nothing
end

@testset "AMDGPU: ragged, all lengths 0..300" begin
    Random.seed!(1)
    msgs = [rand(UInt8, l) for l in 0:300]
    ref = streaming(msgs)
    data, offs = pack_messages(msgs)
    out = ripemd160(ROCArray(data), ROCArray(offs))
    @test out isa ROCMatrix{UInt8}
    @test size(out) == (20, length(msgs))
    @test Array(out) == ref
    @test Array(ripemd160(ROCArray(data), ROCArray(Int32.(offs)))) == ref
    # shuffled order and messages that are not stored consecutively
    perm = shuffle(1:length(msgs))
    data2, offs2 = pack_messages(msgs[perm])
    @test Array(ripemd160(ROCArray(data2), ROCArray(offs2))) == ref[:, perm]
end

@testset "AMDGPU: fixed-length matrix" begin
    Random.seed!(2)
    for len in (0, 1, 3, 55, 56, 63, 64, 65, 119, 120, 128, 1000)
        m = rand(UInt8, len, 1000)
        @test Array(ripemd160(ROCArray(m))) == ripemd160(m)
    end
end

@testset "AMDGPU: single message" begin
    for len in (0, 1, 64, 1000, 100_000)
        m = rand(UInt8, len)
        out = ripemd160(ROCArray(m))
        @test out isa ROCVector{UInt8}
        @test Array(out) == ripemd160(m)
    end
end

@testset "AMDGPU: empty batches" begin
    @test size(ripemd160(ROCArray(UInt8[]), ROCArray([0]))) == (20, 0)
    @test size(ripemd160(ROCArray(zeros(UInt8, 10, 0)))) == (20, 0)
    @test_throws ArgumentError ripemd160(ROCArray(UInt8[]), ROCArray(Int[]))
end

@testset "AMDGPU: large batch (more than one workgroup, odd count)" begin
    Random.seed!(3)
    n = 100_003
    m = rand(UInt8, 32, n)
    @test Array(ripemd160(ROCArray(m))) == ripemd160(m)
    msgs = [rand(UInt8, rand(0:200)) for _ in 1:n]
    data, offs = pack_messages(msgs)
    @test Array(ripemd160(ROCArray(data), ROCArray(offs))) == ripemd160(data, offs)
end

@testset "AMDGPU: known vectors" begin
    data, offs = pack_messages(["", "a", "abc", "message digest",
                                "abcdefghijklmnopqrstuvwxyz",
                                "1234567890" ^ 8])
    out = Array(ripemd160(ROCArray(data), ROCArray(offs)))
    @test bytes2hex(out[:, 1]) == "9c1185a5c5e9fc54612808977ee8f548b2258d31"
    @test bytes2hex(out[:, 2]) == "0bdc9d2d256b3ee9daae347be6f4dc835a467ffe"
    @test bytes2hex(out[:, 3]) == "8eb208f7e05d987a9b044a8e98c6b087f15a0bfc"
    @test bytes2hex(out[:, 4]) == "5d0689ef49d2fae572b881b123a85ffa21595f36"
    @test bytes2hex(out[:, 5]) == "f71c27109c692c1b56bbdceb5b9d2865b3708dbc"
    @test bytes2hex(out[:, 6]) == "9b752e45573d4b39f4dbd3323cab82bf63326bfb"
end
