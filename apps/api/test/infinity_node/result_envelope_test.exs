defmodule InfinityNode.ResultEnvelopeTest do
  use ExUnit.Case, async: true

  alias InfinityNode.ResultEnvelope

  describe "validate/1" do
    test "returns :ok for valid result" do
      result = %{
        job_id: "job-123",
        exit_code: 0,
        stdout_s3_key: "logs/job-123/stdout",
        stderr_s3_key: "logs/job-123/stderr",
        wall_time_ms: 150
      }

      assert ResultEnvelope.validate(result) == :ok
    end

    test "returns error for missing fields" do
      assert {:error, msg} = ResultEnvelope.validate(%{job_id: "job-123"})
      assert msg =~ "Missing result fields"
    end

    test "accepts string keys" do
      result = %{
        "job_id" => "job-123",
        "exit_code" => 0,
        "stdout_s3_key" => "logs/job-123/stdout",
        "stderr_s3_key" => "logs/job-123/stderr",
        "wall_time_ms" => 150
      }

      assert ResultEnvelope.validate(result) == :ok
    end
  end
end
