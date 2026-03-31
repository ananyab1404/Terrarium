defmodule InfinityNode.JobEnvelope do
  @moduledoc """
  Canonical job envelope schema shared across all three apps.

  This is the contract between:
    - Person 3's API (writes to SQS)
    - Person 2's Scheduler (consumes from SQS)
    - Person 1's WorkerProcess (receives via DispatchCoordinator)

  Owned by Person 3. Changes require agreement from all three engineers.
  """

  @type t :: %{
          job_id: String.t(),
          idempotency_key: String.t(),
          function_id: String.t(),
          artifact_s3_key: String.t(),
          input_payload: map(),
          resource_limits: %{
            cpu_shares: pos_integer(),
            memory_mb: pos_integer(),
            timeout_ms: pos_integer()
          },
          retry_count: non_neg_integer(),
          enqueued_at: String.t(),
          tenant_id: String.t()
        }

  @default_cpu_shares 1024
  @default_memory_mb 256
  @default_timeout_ms 30_000
  @max_timeout_ms 300_000

  @doc """
  Builds a new job envelope with defaults applied.

  Required keys in `attrs`: `:function_id`, `:artifact_s3_key`, `:input_payload`
  Optional keys: `:idempotency_key`, `:resource_limits`, `:tenant_id`
  """
  @spec new(map()) :: {:ok, t()} | {:error, :missing_function_id | :missing_artifact}
  def new(attrs) when is_map(attrs) do
    with :ok <- require_key(attrs, :function_id),
         :ok <- require_key(attrs, :artifact_s3_key) do
      envelope = %{
        job_id: generate_uuid(),
        idempotency_key: Map.get(attrs, :idempotency_key, generate_uuid()),
        function_id: Map.fetch!(attrs, :function_id),
        artifact_s3_key: Map.fetch!(attrs, :artifact_s3_key),
        input_payload: Map.get(attrs, :input_payload, %{}),
        resource_limits: normalize_resource_limits(Map.get(attrs, :resource_limits, %{})),
        retry_count: 0,
        enqueued_at: DateTime.utc_now() |> DateTime.to_iso8601(),
        tenant_id: Map.get(attrs, :tenant_id, "public")
      }

      {:ok, envelope}
    end
  end

  @doc "Validates that an existing envelope has all required fields."
  @spec validate(map()) :: :ok | {:error, String.t()}
  def validate(envelope) when is_map(envelope) do
    required = [:job_id, :function_id, :artifact_s3_key, :input_payload, :resource_limits]

    missing =
      required
      |> Enum.reject(&Map.has_key?(envelope, &1))

    case missing do
      [] -> :ok
      keys -> {:error, "Missing required fields: #{inspect(keys)}"}
    end
  end

  @doc "Serializes the envelope to a JSON string for SQS transport."
  @spec to_json(t()) :: {:ok, String.t()} | {:error, term()}
  def to_json(envelope) do
    Jason.encode(envelope)
  end

  @doc "Deserializes a JSON string back into an envelope map."
  @spec from_json(String.t()) :: {:ok, map()} | {:error, term()}
  def from_json(json) when is_binary(json) do
    case Jason.decode(json) do
      {:ok, map} -> {:ok, atomize_keys(map)}
      error -> error
    end
  end

  @doc "Returns default resource limits."
  def default_resource_limits do
    %{
      cpu_shares: @default_cpu_shares,
      memory_mb: @default_memory_mb,
      timeout_ms: @default_timeout_ms
    }
  end

  @doc "Returns maximum allowed timeout in milliseconds."
  def max_timeout_ms, do: @max_timeout_ms

  # --- Private ---

  defp normalize_resource_limits(limits) when is_map(limits) do
    %{
      cpu_shares: get_pos_int(limits, :cpu_shares, "cpu_shares", @default_cpu_shares),
      memory_mb: get_pos_int(limits, :memory_mb, "memory_mb", @default_memory_mb),
      timeout_ms:
        min(
          get_pos_int(limits, :timeout_ms, "timeout_ms", @default_timeout_ms),
          @max_timeout_ms
        )
    }
  end

  defp get_pos_int(map, atom_key, string_key, default) do
    val = Map.get(map, atom_key) || Map.get(map, string_key) || default

    case val do
      v when is_integer(v) and v > 0 -> v
      _ -> default
    end
  end

  defp require_key(map, key) do
    atom_val = Map.get(map, key)
    string_val = Map.get(map, to_string(key))

    if atom_val || string_val do
      :ok
    else
      {:error, :"missing_#{key}"}
    end
  end

  defp generate_uuid do
    <<a::32, b::16, c::16, d::16, e::48>> = :crypto.strong_rand_bytes(16)

    :io_lib.format(
      "~8.16.0b-~4.16.0b-4~3.16.0b-~4.16.0b-~12.16.0b",
      [a, b, c &&& 0x0FFF, d ||| 0x8000 &&& 0xBFFF, e]
    )
    |> to_string()
  end

  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_binary(k) -> {String.to_existing_atom(k), atomize_keys(v)}
      {k, v} -> {k, atomize_keys(v)}
    end)
  rescue
    ArgumentError -> map
  end

  defp atomize_keys(v), do: v
end
