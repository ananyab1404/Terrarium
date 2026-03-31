defmodule InfinityNode.JobEnvelopeTest do
  use ExUnit.Case, async: true

  alias InfinityNode.JobEnvelope

  describe "new/1" do
    test "builds valid envelope with required fields" do
      {:ok, envelope} =
        JobEnvelope.new(%{
          function_id: "func-123",
          artifact_s3_key: "functions/func-123/latest"
        })

      assert envelope.function_id == "func-123"
      assert envelope.artifact_s3_key == "functions/func-123/latest"
      assert is_binary(envelope.job_id)
      assert String.length(envelope.job_id) > 0
      assert envelope.retry_count == 0
      assert envelope.tenant_id == "public"
      assert is_binary(envelope.enqueued_at)
    end

    test "applies default resource limits" do
      {:ok, envelope} =
        JobEnvelope.new(%{
          function_id: "func-123",
          artifact_s3_key: "functions/func-123/latest"
        })

      assert envelope.resource_limits.cpu_shares == 1024
      assert envelope.resource_limits.memory_mb == 256
      assert envelope.resource_limits.timeout_ms == 30_000
    end

    test "respects custom resource limits" do
      {:ok, envelope} =
        JobEnvelope.new(%{
          function_id: "func-123",
          artifact_s3_key: "functions/func-123/latest",
          resource_limits: %{cpu_shares: 2048, memory_mb: 512, timeout_ms: 60_000}
        })

      assert envelope.resource_limits.cpu_shares == 2048
      assert envelope.resource_limits.memory_mb == 512
      assert envelope.resource_limits.timeout_ms == 60_000
    end

    test "caps timeout_ms at max value" do
      {:ok, envelope} =
        JobEnvelope.new(%{
          function_id: "func-123",
          artifact_s3_key: "functions/func-123/latest",
          resource_limits: %{timeout_ms: 999_999}
        })

      assert envelope.resource_limits.timeout_ms == JobEnvelope.max_timeout_ms()
    end

    test "returns error when function_id is missing" do
      result = JobEnvelope.new(%{artifact_s3_key: "something"})
      assert result == {:error, :missing_function_id}
    end

    test "returns error when artifact_s3_key is missing" do
      result = JobEnvelope.new(%{function_id: "func-123"})
      assert result == {:error, :missing_artifact_s3_key}
    end

    test "uses provided idempotency_key" do
      {:ok, envelope} =
        JobEnvelope.new(%{
          function_id: "func-123",
          artifact_s3_key: "functions/func-123/latest",
          idempotency_key: "my-custom-key"
        })

      assert envelope.idempotency_key == "my-custom-key"
    end

    test "generates unique job_ids" do
      {:ok, e1} = JobEnvelope.new(%{function_id: "f", artifact_s3_key: "s"})
      {:ok, e2} = JobEnvelope.new(%{function_id: "f", artifact_s3_key: "s"})
      assert e1.job_id != e2.job_id
    end
  end

  describe "validate/1" do
    test "returns :ok for valid envelope" do
      {:ok, envelope} =
        JobEnvelope.new(%{function_id: "f", artifact_s3_key: "s"})

      assert JobEnvelope.validate(envelope) == :ok
    end

    test "returns error for missing fields" do
      assert {:error, msg} = JobEnvelope.validate(%{})
      assert msg =~ "Missing required fields"
    end
  end

  describe "to_json/1 and from_json/1" do
    test "round-trips through JSON" do
      {:ok, envelope} =
        JobEnvelope.new(%{
          function_id: "func-123",
          artifact_s3_key: "functions/func-123/latest",
          input_payload: %{key: "value"}
        })

      {:ok, json} = JobEnvelope.to_json(envelope)
      assert is_binary(json)

      {:ok, decoded} = JobEnvelope.from_json(json)
      assert decoded.function_id == "func-123"
    end
  end

  describe "default_resource_limits/0" do
    test "returns expected defaults" do
      defaults = JobEnvelope.default_resource_limits()
      assert defaults.cpu_shares == 1024
      assert defaults.memory_mb == 256
      assert defaults.timeout_ms == 30_000
    end
  end
end
