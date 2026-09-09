using Ripemd, Test

files = readdir(".")

# use only files that are named test_*.jl and start with the newest

if VERSION < v"0.7.0"
    filter!(x -> contains(x, r"^test_"), files)
else
    filter!(x -> occursin(r"^test_", x), files)
end

sort!(files, by = x -> stat(x).mtime, rev = true)

for f in files
    include(f)
end

