defmodule Worker.VsockChannel do
  @moduledoc false

  require Logger

  @stdout_type 0x00
  @stderr_type 0x01
  @terminator 0xFF
  @max_chunk_bytes 8_388_608
  @default_timeout_ms 30_000

  def inject(socket_path, job) do
    timeout_ms = timeout_ms(job)

    with {:ok, artifact_bytes} <- artifact_bytes(job),
         {:ok, payload_bytes} <- payload_bytes(job),
         {:ok, socket} <- connect(socket_path, timeout_ms) do
      try do
        :socket.send(socket, encode_inbound(artifact_bytes, payload_bytes))
      after
        :socket.close(socket)
      end
    else
      {:error, reason} ->
        Logger.warning("vsock inject failed for #{job_id(job)}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def collect(socket_path, timeout_ms) when is_integer(timeout_ms) and timeout_ms > 0 do
    deadline_ms = System.monotonic_time(:millisecond) + timeout_ms

    with {:ok, socket} <- connect(socket_path, timeout_ms) do
      try do
        read_stream(socket, deadline_ms, %{stdout: [], stderr: []})
      after
        :socket.close(socket)
      end
    end
  end

  def collect(_socket_path, _timeout_ms), do: {:error, :invalid_timeout}

  def encode_inbound(artifact_bytes, payload_bytes)
      when is_binary(artifact_bytes) and is_binary(payload_bytes) do
    <<byte_size(artifact_bytes)::unsigned-big-32, artifact_bytes::binary,
      byte_size(payload_bytes)::unsigned-big-32, payload_bytes::binary>>
  end

  def decode_outbound(binary) when is_binary(binary) do
    case parse_frames(binary, %{stdout: [], stderr: []}) do
      {:ok, acc, <<>>} ->
        {:ok,
         %{
           stdout: acc.stdout |> Enum.reverse() |> IO.iodata_to_binary(),
           stderr: acc.stderr |> Enum.reverse() |> IO.iodata_to_binary(),
           exit_code: acc.exit_code,
           peak_memory_bytes: 0
         }}

      {:ok, _acc, rest} ->
        {:error, {:trailing_bytes, byte_size(rest)}}

      {:error, reason} ->
        {:error, reason}

      :incomplete ->
        {:error, :incomplete_frame}
    end
  end

  defp parse_frames(<<@terminator, exit_code::unsigned-big-32, rest::binary>>, acc) do
    {:ok, Map.put(acc, :exit_code, exit_code), rest}
  end

  defp parse_frames(<<stream_type, size::unsigned-big-32, rest::binary>>, acc)
       when stream_type in [@stdout_type, @stderr_type] do
    cond do
      size > @max_chunk_bytes ->
        {:error, {:chunk_too_large, size}}

      byte_size(rest) < size ->
        :incomplete

      true ->
        <<chunk::binary-size(size), tail::binary>> = rest

        next_acc =
          case stream_type do
            @stdout_type -> Map.update!(acc, :stdout, &[chunk | &1])
            @stderr_type -> Map.update!(acc, :stderr, &[chunk | &1])
          end

        parse_frames(tail, next_acc)
    end
  end

  defp parse_frames(<<>>, _acc), do: :incomplete
  defp parse_frames(<<stream_type, _rest::binary>>, _acc), do: {:error, {:unknown_stream_type, stream_type}}

  defp read_stream(socket, deadline_ms, acc) do
    with {:ok, <<stream_type>>} <- recv_exact(socket, 1, deadline_ms) do
      case stream_type do
        @terminator ->
          with {:ok, <<exit_code::unsigned-big-32>>} <- recv_exact(socket, 4, deadline_ms) do
            {:ok,
             %{
               stdout: acc.stdout |> Enum.reverse() |> IO.iodata_to_binary(),
               stderr: acc.stderr |> Enum.reverse() |> IO.iodata_to_binary(),
               exit_code: exit_code,
               peak_memory_bytes: 0
             }}
          end

        @stdout_type ->
          with {:ok, <<size::unsigned-big-32>>} <- recv_exact(socket, 4, deadline_ms),
               :ok <- validate_chunk_size(size),
               {:ok, chunk} <- recv_exact(socket, size, deadline_ms) do
            read_stream(socket, deadline_ms, %{acc | stdout: [chunk | acc.stdout]})
          end

        @stderr_type ->
          with {:ok, <<size::unsigned-big-32>>} <- recv_exact(socket, 4, deadline_ms),
               :ok <- validate_chunk_size(size),
               {:ok, chunk} <- recv_exact(socket, size, deadline_ms) do
            read_stream(socket, deadline_ms, %{acc | stderr: [chunk | acc.stderr]})
          end

        _ ->
          {:error, {:unknown_stream_type, stream_type}}
      end
    end
  end

  defp validate_chunk_size(size) when size > @max_chunk_bytes, do: {:error, {:chunk_too_large, size}}
  defp validate_chunk_size(_size), do: :ok

  defp recv_exact(_socket, 0, _deadline_ms), do: {:ok, <<>>}

  defp recv_exact(socket, bytes_needed, deadline_ms) do
    now = System.monotonic_time(:millisecond)
    remaining_ms = max(deadline_ms - now, 0)

    if remaining_ms == 0 do
      {:error, :timeout}
    else
      do_recv_exact(socket, bytes_needed, remaining_ms, <<>>)
    end
  end

  defp do_recv_exact(_socket, 0, _timeout_ms, acc), do: {:ok, acc}

  defp do_recv_exact(socket, bytes_needed, timeout_ms, acc) do
    case :socket.recv(socket, bytes_needed, timeout_ms) do
      {:ok, chunk} when is_binary(chunk) ->
        do_recv_exact(socket, bytes_needed - byte_size(chunk), timeout_ms, <<acc::binary, chunk::binary>>)

      {:ok, _non_binary} ->
        {:error, :invalid_socket_data}

      {:error, :closed} ->
        {:error, :channel_closed}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp connect(socket_path, timeout_ms) when is_binary(socket_path) do
    with {:ok, socket} <- :socket.open(:local, :stream, :default) do
      case :socket.connect(socket, %{family: :local, path: to_charlist(socket_path)}, timeout_ms) do
        :ok -> {:ok, socket}
        {:error, reason} ->
          :socket.close(socket)
          {:error, {:connect_failed, reason}}
      end
    end
  end

  defp timeout_ms(%{resource_limits: %{timeout_ms: ms}}) when is_integer(ms) and ms > 0, do: ms
  defp timeout_ms(_), do: @default_timeout_ms

  defp payload_bytes(%{input_payload: payload}) when is_binary(payload), do: {:ok, payload}

  defp payload_bytes(%{input_payload: payload}) do
    case Jason.encode(payload) do
      {:ok, encoded} -> {:ok, encoded}
      {:error, reason} -> {:error, {:invalid_payload, reason}}
    end
  end

  defp payload_bytes(_), do: {:ok, "{}"}

  defp artifact_bytes(%{artifact_bytes: bytes}) when is_binary(bytes), do: {:ok, bytes}

  defp artifact_bytes(%{"artifact_bytes" => bytes}) when is_binary(bytes), do: {:ok, bytes}

  defp artifact_bytes(%{artifact_path: path}) when is_binary(path), do: File.read(path)

  defp artifact_bytes(%{"artifact_path" => path}) when is_binary(path), do: File.read(path)

  defp artifact_bytes(%{artifact_base64: value}) when is_binary(value), do: Base.decode64(value)

  defp artifact_bytes(%{"artifact_base64" => value}) when is_binary(value), do: Base.decode64(value)

  defp artifact_bytes(%{artifact_s3_key: key}) when is_binary(key), do: download_artifact(key)

  defp artifact_bytes(%{"artifact_s3_key" => key}) when is_binary(key), do: download_artifact(key)

  defp artifact_bytes(_), do: {:error, :missing_artifact}

  defp download_artifact(key) do
    bucket =
      Application.get_env(:worker, :artifacts_bucket, System.get_env("ARTIFACTS_BUCKET", "infinity-node-artifacts"))

    case ExAws.S3.get_object(bucket, key) |> ExAws.request() do
      {:ok, %{body: body}} when is_binary(body) -> {:ok, body}
      {:ok, %{body: body}} -> {:ok, IO.iodata_to_binary(body)}
      {:error, reason} -> {:error, {:artifact_download_failed, reason}}
    end
  end

  defp job_id(%{job_id: id}), do: id
  defp job_id(_), do: "unknown-job"
end
