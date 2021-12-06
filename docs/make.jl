using DTCInitium
using Documenter

DocMeta.setdocmeta!(DTCInitium, :DocTestSetup, :(using DTCInitium); recursive=true)

makedocs(;
    modules=[DTCInitium],
    authors="Paulo Jabardo <pjabardo@ipt.br>",
    repo="https://github.com/pjsjipt/DTCInitium.jl/blob/{commit}{path}#{line}",
    sitename="DTCInitium.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)
