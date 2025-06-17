defmodule TestLlm.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/dualohq/test_llm"

  def project do
    [
      app: :test_llm,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      docs: docs(),
      deps: deps(),
      package: package(),
      description: description()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:req, "~> 0.5"},
      {:plug, "~> 1.16"},
      {:slugify, "~> 1.3"},
      {:bypass, "~> 2.1"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end

  defp description do
    "Utility for stubbing LLM requests in Elixir tests."
  end

  # https://hexdocs.pm/hex/Mix.Tasks.Hex.Build.html#module-package-configuration
  defp package do
    [
      name: "test_llm",
      maintainers: ["Michael Bearne"],
      links: %{"GitHub" => @source_url},
      licenses: ["SEE LICENSE IN LICENSE"],
      organization: "dualo"
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"],
      source_ref: "v#{@version}",
      source_url: @source_url
    ]
  end
end
