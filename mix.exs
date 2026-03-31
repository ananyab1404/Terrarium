defmodule InfinityNode.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "0.1.0",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  defp deps do
    [
      {:ex_aws, "~> 2.5"},
      {:ex_aws_s3, "~> 2.5"},
      {:ex_aws_sqs, "~> 3.4"},
      {:ex_aws_dynamo, "~> 4.2"},
      {:hackney, "~> 1.20"},
      {:jason, "~> 1.4"},
      {:telemetry, "~> 1.2"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"}
    ]
  end
end
