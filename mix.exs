defmodule AIToolsBlocklist.MixProject do
  use Mix.Project

  def project,
    do: [
      app: :aitoolsblocklist,
      version: "1.0.0",
      elixir: "~> 1.14",
      description: "Elixir client for AI Tools Blocklist.",
      package: package(),
      deps: deps(),
      docs: [main: "readme", extras: ["README.md"]],
      source_url: "https://github.com/explainableaixai/aitoolsblocklist-elixir",
      homepage_url: "https://www.aitoolsblocklist.com"
    ]

  def application, do: [extra_applications: [:logger]]
  defp deps, do: [{:req, "~> 0.5"}, {:ex_doc, "~> 0.34", only: :dev, runtime: false}]

  defp package,
    do: [
      licenses: ["MIT"],
      files: ~w(lib mix.exs README.md CHANGELOG.md LICENSE),
      links: %{
        "Homepage" => "https://www.aitoolsblocklist.com",
        "GitHub" => "https://github.com/explainableaixai/aitoolsblocklist-elixir"
      }
    ]
end
