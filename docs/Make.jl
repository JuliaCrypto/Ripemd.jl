using Documenter
using Ripemd

makedocs(
    sitename = "Ripemd.jl",
    modules  = [Ripemd],
    format   = Documenter.HTML(
        prettyurls = get(ENV, "CI", nothing) == "true",
    ),
    pages = [
        "Home" => "index.md",
    ],
    # Fail the build if a docstring references a symbol that doesn't exist,
    # or if an exported symbol is missing a docstring. Relax to :warn while
    # you're first setting things up if this is too strict.
    checkdocs = :exports,
)

deploydocs(
    repo = "github.com/USER_OR_ORG/Ripemd.jl.git",
    devbranch = "main",
)
