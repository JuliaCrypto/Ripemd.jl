# Tests for the batch API (CPU backend). The GPU backend is tested in
# test/amdgpu/runtests.jl because it needs AMDGPU.jl and a GPU.

@testset "batch: pack_messages" begin
    data, offs = pack_messages(["", "a", "abc"])
    @test data == UInt8['a', 'a', 'b', 'c']
    @test offs == [0, 0, 1, 4]
    data, offs = pack_messages([UInt8[1, 2], UInt8[], UInt8[3]])
    @test data == UInt8[1, 2, 3]
    @test offs == [0, 2, 2, 3]
end

@testset "batch: ragged vs streaming, all lengths 0..300" begin
    msgs = [rand(UInt8, l) for l in 0:300]
    ref = hcat([ripemd160(m) for m in msgs]...)
    data, offs = pack_messages(msgs)
    out = ripemd160(data, offs)
    @test size(out) == (20, length(msgs))
    @test out == ref
    # Int32 offsets and a non-Vector data container
    @test ripemd160(data, Int32.(offs)) == ref
    @test ripemd160(view(data, :), offs) == ref
    # empty batch
    @test size(ripemd160(UInt8[], [0])) == (20, 0)
    @test_throws ArgumentError ripemd160(UInt8[], Int[])
end

@testset "batch: fixed-length matrix vs streaming" begin
    for len in (0, 1, 3, 55, 56, 64, 65, 120, 128, 1000)
        m = rand(UInt8, len, 17)
        ref = hcat([ripemd160(m[:, i]) for i in 1:17]...)
        @test ripemd160(m) == ref
    end
    @test size(ripemd160(zeros(UInt8, 10, 0))) == (20, 0)
end

@testset "batch: known vectors" begin
    data, offs = pack_messages(["", "a", "abc", "message digest",
                                "abcdefghijklmnopqrstuvwxyz",
                                "1234567890" ^ 8])
    out = ripemd160(data, offs)
    @test bytes2hex(out[:, 1]) == "9c1185a5c5e9fc54612808977ee8f548b2258d31"
    @test bytes2hex(out[:, 2]) == "0bdc9d2d256b3ee9daae347be6f4dc835a467ffe"
    @test bytes2hex(out[:, 3]) == "8eb208f7e05d987a9b044a8e98c6b087f15a0bfc"
    @test bytes2hex(out[:, 4]) == "5d0689ef49d2fae572b881b123a85ffa21595f36"
    @test bytes2hex(out[:, 5]) == "f71c27109c692c1b56bbdceb5b9d2865b3708dbc"
    @test bytes2hex(out[:, 6]) == "9b752e45573d4b39f4dbd3323cab82bf63326bfb"
end
