defmodule Worker.VsockChannelTest do
  use ExUnit.Case, async: true

  alias Worker.VsockChannel

  test "encode_inbound/2 writes 4-byte size prefixes" do
    artifact = "abc"
    payload = ~s({"x":1})

    packet = VsockChannel.encode_inbound(artifact, payload)

    assert <<3::unsigned-big-32, "abc", 7::unsigned-big-32, "{\"x\":1}">> = packet
  end

  test "decode_outbound/1 merges stdout/stderr chunks and returns exit code" do
    stream =
      <<0x00, 5::unsigned-big-32, "hello", 0x01, 5::unsigned-big-32, "warn!", 0x00,
        6::unsigned-big-32, " world", 0xFF, 7::unsigned-big-32>>

    assert {:ok, result} = VsockChannel.decode_outbound(stream)
    assert result.stdout == "hello world"
    assert result.stderr == "warn!"
    assert result.exit_code == 7
    assert result.peak_memory_bytes == 0
  end

  test "decode_outbound/1 detects unknown stream type" do
    assert {:error, {:unknown_stream_type, 0x42}} =
             VsockChannel.decode_outbound(<<0x42, 0, 0, 0, 1, 0x61>>)
  end

  test "decode_outbound/1 detects incomplete frame" do
    assert {:error, :incomplete_frame} =
             VsockChannel.decode_outbound(<<0x00, 0, 0, 0, 3, 0x61>>)
  end
end
