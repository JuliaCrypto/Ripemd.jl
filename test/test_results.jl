# Compute RIPEMD160 via a direct FFI call into libcrypto's EVP API,
# instead of shelling out to the `openssl` CLI with backticks.
#
# This resolves the digest by name at call time (EVP_get_digestbyname),
# which works across OpenSSL 1.1.x and 3.x, then computes a one-shot
# digest with EVP_Digest. 

const LIBCRYPTO = "libcrypto"

const ROCKY_SPEECH = "I'd hold you up to say to your mother, 'this kid's gonna be the best kid in the world. This kid's gonna be somebody better than anybody I ever knew.' And you grew up good and wonderful. It was great just watching you, every day was like a privilege. Then the time come for you to be your own man and take on the world, and you did. But somewhere along the line, you changed. You stopped being you. You let people stick a finger in your face and tell you you're no good. And when things got hard, you started looking for something to blame, like a big shadow. Let me tell you something you already know. The world ain't all sunshine and rainbows. It's a very mean and nasty place and I don't care how tough you are it will beat you to your knees and keep you there permanently if you let it. You, me, or nobody is gonna hit as hard as life. But it ain't about how hard ya hit. It's about how hard you can get hit and keep moving forward. How much you can take and keep moving forward. That's how winning is done! Now if you know what you're worth then go out and get what you're worth. But ya gotta be willing to take the hits, and not pointing fingers saying you ain't where you wanna be because of him, or her, or anybody! Cowards do that and that ain't you! You're better than that! I'm always gonna love you no matter what. No matter what happens. You're my son and you're my blood. You're the best thing in my life. But until you start believing in yourself, ya ain't gonna have a life. Don't forget to visit your mother."
const ROCKY_RIPEMD160 = "fff55c23c197b4fded67e09424e5aef9dafad1c6"

function openssl_ripemd160_bytes(data::Vector{UInt8})
    md = ccall((:EVP_get_digestbyname, LIBCRYPTO), Ptr{Cvoid}, (Cstring,), "RIPEMD160")
    md == C_NULL && error("RIPEMD160 not available in this OpenSSL build " *
                           "(OpenSSL 3.x may need the 'legacy' provider loaded)")

    out = Vector{UInt8}(undef, 20)   # EVP_MAX_MD_SIZE-safe for RIPEMD160 (160 bit = 20 bytes)
    outlen = Ref{Cuint}(0)

    ret = ccall((:EVP_Digest, LIBCRYPTO), Cint,
                (Ptr{UInt8}, Csize_t, Ptr{UInt8}, Ptr{Cuint}, Ptr{Cvoid}, Ptr{Cvoid}),
                data, length(data), out, outlen, md, C_NULL)
    ret == 1 || error("EVP_Digest failed")

    return bytes2hex(out)
end

# --- Dispatch wrappers matching the shapes used in the original tests ---

openssl_ripemd160(x::AbstractString) = openssl_ripemd160_bytes(Vector{UInt8}(codeunits(x)))
openssl_ripemd160(x::Array{UInt8,1}) = openssl_ripemd160_bytes(x)
openssl_ripemd160(x::NTuple{N,UInt8}) where {N} = openssl_ripemd160_bytes(collect(x))

function vs_openssl(x)
    bytes2hex(Ripemd.ripemd160(x)) == openssl_ripemd160(x)
end

@testset "Ripemd160 vs openssl a's" begin
    for i in 1:1000
        x = [0x61 for j in 1:i]
        @test vs_openssl(x)
    end
    for i in 1:1000
        x = *(["a" for j in 1:i]...,)
        @test vs_openssl(x)
    end
    # This takes a long time, because Julia will compile a different function
    # for each length/loop iterations
    for i in 1:10
        x = ntuple(x -> 0x61, i)
        @test vs_openssl(x)
    end
end

@testset "Ripemd160 vs openssl abc" begin
    d = Ripemd.codeunits("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
    for i in 1:1000
        x = [d[j % length(d) + 1] for j in 1:i]
        @test vs_openssl(x)
    end
    for i in 1:1000
        x = *([Char(d[j % length(d) + 1]) for j in 1:i]...,)
        @test vs_openssl(x)
    end
    # This takes a long time, because Julia will compile a different function
    # for each length/loop iterations
    for i in 1:10
        x = ntuple(j -> d[j % length(d) + 1], i)
        @test vs_openssl(x)
    end
end

@testset "Ripemd160 1M a's" begin

    d1 = [0x61 for i in 1:1_000_000]
    d2 = ntuple((i) -> 0x61, 1_000_000)
    r = "52783243c1697bdbe16d37f97f68f08325dc1528"

    @test bytes2hex(Ripemd.ripemd160(d1)) == r
    @test bytes2hex(Ripemd.ripemd160(d2)) == r
end

@testset "Ripemd160" begin
    @test bytes2hex(Ripemd.ripemd160("asdf")) ==
        "0ef2aed6346def670a8019e4ea42cf4c76018139"
    @test bytes2hex(Ripemd.ripemd160("")) ==
        "9c1185a5c5e9fc54612808977ee8f548b2258d31"
    @test bytes2hex(Ripemd.ripemd160("a")) ==
        "0bdc9d2d256b3ee9daae347be6f4dc835a467ffe"
    @test bytes2hex(Ripemd.ripemd160("abc")) ==
        "8eb208f7e05d987a9b044a8e98c6b087f15a0bfc"
    @test bytes2hex(Ripemd.ripemd160("message digest")) ==
        "5d0689ef49d2fae572b881b123a85ffa21595f36"
    @test bytes2hex(Ripemd.ripemd160("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")) ==
        "b0e20b6e3116640286ed3a87a5713079b21f5189"

    @test bytes2hex(Ripemd.ripemd160(ROCKY_SPEECH)) == ROCKY_RIPEMD160

    @test bytes2hex(Ripemd.ripemd160(Ripemd.codeunits("asdf"))) ==
        "0ef2aed6346def670a8019e4ea42cf4c76018139"
    @test bytes2hex(Ripemd.ripemd160(Ripemd.codeunits(""))) ==
        "9c1185a5c5e9fc54612808977ee8f548b2258d31"
    @test bytes2hex(Ripemd.ripemd160(Ripemd.codeunits("a"))) ==
        "0bdc9d2d256b3ee9daae347be6f4dc835a467ffe"
    @test bytes2hex(Ripemd.ripemd160(Ripemd.codeunits("abc"))) ==
        "8eb208f7e05d987a9b044a8e98c6b087f15a0bfc"
    @test bytes2hex(Ripemd.ripemd160(Ripemd.codeunits("message digest"))) ==
        "5d0689ef49d2fae572b881b123a85ffa21595f36"
    @test bytes2hex(Ripemd.ripemd160(Ripemd.codeunits("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"))) ==
        "b0e20b6e3116640286ed3a87a5713079b21f5189"
    @test bytes2hex(Ripemd.ripemd160(Ripemd.codeunits(ROCKY_SPEECH))) == ROCKY_RIPEMD160

    @test bytes2hex(Ripemd.ripemd160((Ripemd.codeunits("asdf")...,))) ==
        "0ef2aed6346def670a8019e4ea42cf4c76018139"
    @test bytes2hex(Ripemd.ripemd160((Ripemd.codeunits("")...,))) ==
        "9c1185a5c5e9fc54612808977ee8f548b2258d31"
    @test bytes2hex(Ripemd.ripemd160((Ripemd.codeunits("a")...,))) ==
        "0bdc9d2d256b3ee9daae347be6f4dc835a467ffe"
    @test bytes2hex(Ripemd.ripemd160((Ripemd.codeunits("abc")...,))) ==
        "8eb208f7e05d987a9b044a8e98c6b087f15a0bfc"
    @test bytes2hex(Ripemd.ripemd160((Ripemd.codeunits("message digest")...,))) ==
        "5d0689ef49d2fae572b881b123a85ffa21595f36"
    @test bytes2hex(Ripemd.ripemd160((Ripemd.codeunits("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")...,))) ==
        "b0e20b6e3116640286ed3a87a5713079b21f5189"
    @test bytes2hex(Ripemd.ripemd160((Ripemd.codeunits(ROCKY_SPEECH)...,))) == ROCKY_RIPEMD160
end

# Tests for the convenience functions layered on top of the core
# byte-vector implementation: update!(ctx, ::AbstractString),
# update!(ctx, ::IO), ripemd160(::IO), ripemd160_file, and ripemd160_hex.
const ALPHANUM = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"

const VECTORS = Dict(
    ""               => "9c1185a5c5e9fc54612808977ee8f548b2258d31",
    "a"              => "0bdc9d2d256b3ee9daae347be6f4dc835a467ffe",
    "abc"            => "8eb208f7e05d987a9b044a8e98c6b087f15a0bfc",
    "asdf"           => "0ef2aed6346def670a8019e4ea42cf4c76018139",
    "message digest" => "5d0689ef49d2fae572b881b123a85ffa21595f36",
    ALPHANUM         => "b0e20b6e3116640286ed3a87a5713079b21f5189",
)

@testset "update!(ctx, ::AbstractString) matches update!(ctx, ::Vector{UInt8})" begin
    for (s, hex) in VECTORS
        ctx_str = Ripemd.RIPEMD160_CTX()
        Ripemd.update!(ctx_str, s)

        ctx_bytes = Ripemd.RIPEMD160_CTX()
        Ripemd.update!(ctx_bytes, Vector{UInt8}(codeunits(s)))

        @test bytes2hex(Ripemd.digest!(ctx_str)) == bytes2hex(Ripemd.digest!(ctx_bytes))
        @test bytes2hex(Ripemd.digest!(ctx_str)) == hex
    end

    # Splitting a single string across several update! calls should give
    # the same result as one call with the concatenation.
    ctx = Ripemd.RIPEMD160_CTX()
    Ripemd.update!(ctx, "message ")
    Ripemd.update!(ctx, "digest")
    @test bytes2hex(Ripemd.digest!(ctx)) == VECTORS["message digest"]
end

@testset "update!(ctx, ::IO) matches update!(ctx, ::Vector{UInt8})" begin
    for (s, hex) in VECTORS
        data = Vector{UInt8}(codeunits(s))
        for chunk_size in (1, 3, 7, 64, 4096)
            ctx = Ripemd.RIPEMD160_CTX()
            Ripemd.update!(ctx, IOBuffer(data); chunk_size = chunk_size)
            @test bytes2hex(Ripemd.digest!(ctx)) == hex
        end
    end

    big = repeat(UInt8('a'), 1000)
    ctx_io = Ripemd.RIPEMD160_CTX()
    Ripemd.update!(ctx_io, IOBuffer(big); chunk_size = 13)

    ctx_bytes = Ripemd.RIPEMD160_CTX()
    Ripemd.update!(ctx_bytes, big)

    @test bytes2hex(Ripemd.digest!(ctx_io)) == bytes2hex(Ripemd.digest!(ctx_bytes))
end

@testset "ripemd160(::IO) matches ripemd160(::Vector{UInt8}) and known vectors" begin
    for (s, hex) in VECTORS
        data = Vector{UInt8}(codeunits(s))
        @test bytes2hex(Ripemd.ripemd160(IOBuffer(data))) == hex
        @test bytes2hex(Ripemd.ripemd160(IOBuffer(data))) == bytes2hex(Ripemd.ripemd160(data))
    end

    # 1,000,000 a's, streamed through an IOBuffer rather than materialized
    # as a single update! call, exercises the multi-chunk read loop.
    r = "52783243c1697bdbe16d37f97f68f08325dc1528"
    million_a = repeat(UInt8('a'), 1_000_000)
    @test bytes2hex(Ripemd.ripemd160(IOBuffer(million_a))) == r
end

@testset "ripemd160_file matches ripemd160(::Vector{UInt8})" begin
    for (s, hex) in VECTORS
        path, io = mktemp()
        write(io, s)
        close(io)
        try
            @test bytes2hex(Ripemd.ripemd160_file(path)) == hex
        finally
            rm(path; force = true)
        end
    end

    # A file whose size is an exact multiple of the default chunk_size
    # (4096), to make sure the read loop terminates cleanly on eof()
    # right at a chunk boundary instead of looping or truncating.
    path, io = mktemp()
    write(io, repeat(UInt8('a'), 4096 * 3))
    close(io)
    try
        expected = bytes2hex(Ripemd.ripemd160(repeat(UInt8('a'), 4096 * 3)))
        @test bytes2hex(Ripemd.ripemd160_file(path)) == expected
    finally
        rm(path; force = true)
    end
end

@testset "ripemd160_hex matches bytes2hex(ripemd160(...)) and known vectors" begin
    for (s, hex) in VECTORS
        @test Ripemd.ripemd160_hex(s) == hex
        @test Ripemd.ripemd160_hex(s) == bytes2hex(Ripemd.ripemd160(s))
    end

    # ripemd160_hex should dispatch through the same generic `data`
    # argument for bytes, tuples, and strings.
    @test Ripemd.ripemd160_hex(Vector{UInt8}(codeunits("abc"))) == VECTORS["abc"]
    @test Ripemd.ripemd160_hex((Vector{UInt8}(codeunits("abc"))...,)) == VECTORS["abc"]
end

true
