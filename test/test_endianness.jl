using Ripemd
using Test

@testset "endianness check" begin
    @test Ripemd.check_endianness() === nothing          # this machine
    @test Ripemd.check_endianness(0x04030201) === nothing # little endian
    @test_throws ErrorException Ripemd.check_endianness(0x01020304) # big endian
end
