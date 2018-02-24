using Ripemd
using Base.Test

files = readdir(".")

# use only files that are named test_*.jl and start with the newest

filter!(x -> contains(x, r"^test_"), files)
sort!(files, by = x -> stat(x).mtime, rev = true)

for f in files
    include(f)
end

