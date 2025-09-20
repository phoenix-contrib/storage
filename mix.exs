defmodule PhoenixContribStorage.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/phoenix-contrib/storage"

  def project do
    [
      app: :phoenix_contrib_storage,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: [],
      name: "PhoenixContribStorage",
      source_url: @source_url,
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.json": :test
      ],
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        plt_add_apps: [:mix, :ex_unit]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ecto, "~> 3.10"},
      {:ecto_sql, "~> 3.10"},
      {:phoenix, "~> 1.7"},
      {:phoenix_live_view, "~> 0.20"},
      {:plug, "~> 1.14"},
      {:jason, "~> 1.4"},
      {:mime, "~> 2.0"},
      {:ex_aws, "~> 2.4", optional: true},
      {:ex_aws_s3, "~> 2.4", optional: true},
      {:hackney, "~> 1.18", optional: true},
      {:sweet_xml, "~> 0.7", optional: true},
      {:image, "~> 0.37", optional: true},
      {:ex_doc, "~> 0.29", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.3", only: [:dev], runtime: false},
      {:excoveralls, "~> 0.16", only: :test},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false}
    ]
  end

  defp description do
    "ActiveStorage-like file storage for Phoenix. All things file uploads for your Phoenix app."
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      maintainers: ["Phoenix Contributors"]
    ]
  end

  # FIXME: Publishing docs require some Hex configuration in the account
  # Figure out
  defp docs do
    [
      main: "Storage",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extras: ["README.md"]
    ]
  end
end
