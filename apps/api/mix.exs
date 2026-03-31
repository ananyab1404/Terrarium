defmodule Api.MixProject do
  use Mix.Project

  def project do
    [
      app: :api,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Api.Application, []}
    ]
  end

  defp deps do
    [
      # Phoenix
      {:phoenix, "~> 1.7"},
      {:phoenix_live_dashboard, "~> 0.8"},
      {:phoenix_live_view, "~> 0.20"},
      {:plug_cowboy, "~> 2.7"},
      {:jason, "~> 1.4"},

      # AWS
      {:ex_aws, "~> 2.5"},
      {:ex_aws_dynamo, "~> 4.2"},
      {:ex_aws_s3, "~> 2.5"},
      {:ex_aws_sqs, "~> 3.4"},

      # Telemetry
      {:telemetry, "~> 1.2"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},

      # Umbrella
      {:scheduler, in_umbrella: true}
    ]
  end
end
