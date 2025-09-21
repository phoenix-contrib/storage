Code.eval_file("../../helpers/mix_helpers.ex")

defmodule PhoenixContribStorageExS3.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/phoenix-contrib/storage_ex"

  def project do
    [
      app: :phoenix_contrib_storage_s3_ex,
      name: "StorageExS3",
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      source_url: @source_url,
      aliases: MixHelpers.common_aliases()
    ] ++
      MixHelpers.shared_paths() ++
      MixHelpers.common_project_config()
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp description do
    "S3-compatible storage provider for phoenix_contrib_storage. Works with AWS S3, Cloudflare R2, DigitalOcean Spaces, and other S3-compatible services."
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      maintainers: ["andresgutgon"],
      files: ~w(lib mix.exs README.md)
    ]
  end

  defp docs do
    [
      main: "StorageExS3.Service",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extras: ["README.md"]
    ]
  end

  defp deps do
    [
      {:phoenix_contrib_storage_ex, path: "../storage_ex"},
      {:ex_aws, "~> 2.4"},
      {:ex_aws_s3, "~> 2.4"},
      {:hackney, "~> 1.18"},
      {:sweet_xml, "~> 0.7"}
    ] ++ MixHelpers.deps()
  end
end
