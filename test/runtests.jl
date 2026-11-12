using Ripemd
using Test

# Run every test/test_*.jl in a fixed (alphabetical) order, independent of
# the working directory and of file modification times.
const TEST_DIR = @__DIR__
const TEST_FILES = sort!(filter(f -> occursin(r"^test_.*\.jl$", f), readdir(TEST_DIR)))

@testset "Ripemd" begin
    for f in TEST_FILES
        include(joinpath(TEST_DIR, f))
    end
end
