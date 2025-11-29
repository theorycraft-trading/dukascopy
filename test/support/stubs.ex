defmodule DukascopyEx.TestStubs do
  @moduledoc false

  # Default options for all stubs (disable retry logging and speed up retries in tests)
  @default_opts [retry_log_level: false, retry_delay: 0]

  ## Public API

  @doc """
  Creates a stub that returns different responses on each call.

  Useful for testing retry logic where the first N calls fail and then succeed.

  ## Example

      {opts, counter} =
        TestStubs.counting_stub(:my_test, [
          {500, ""},           # 1st call: 500 error
          {500, ""},           # 2nd call: 500 error
          {200, valid_data}    # 3rd call: success
        ])

      Client.fetch(path, opts)
      assert :counters.get(counter, 1) == 3
  """
  def counting_stub(name, responses) when is_list(responses) do
    counter = :counters.new(1, [:atomics])

    Req.Test.stub(name, fn conn ->
      idx = :counters.get(counter, 1)
      :counters.add(counter, 1, 1)

      {status, body} = Enum.at(responses, idx, List.last(responses))
      Plug.Conn.send_resp(conn, status, body)
    end)

    {[plug: {Req.Test, name}] ++ @default_opts, counter}
  end

  @doc """
  Creates a stub that returns a fixed response.
  """
  def fixed_stub(name, status, body \\ "") do
    Req.Test.stub(name, fn conn ->
      Plug.Conn.send_resp(conn, status, body)
    end)

    [plug: {Req.Test, name}] ++ @default_opts
  end

  @doc """
  Creates a stub that simulates a transport error (timeout, connection refused, etc).
  """
  def transport_error_stub(name, reason) do
    Req.Test.stub(name, fn conn ->
      Req.Test.transport_error(conn, reason)
    end)

    [plug: {Req.Test, name}] ++ @default_opts
  end

  @doc """
  Creates a stub with a counter that always returns the same response.

  Useful for verifying how many times the client called the server.
  """
  def counting_fixed_stub(name, status, body \\ "") do
    counter = :counters.new(1, [:atomics])

    Req.Test.stub(name, fn conn ->
      :counters.add(counter, 1, 1)
      Plug.Conn.send_resp(conn, status, body)
    end)

    {[plug: {Req.Test, name}] ++ @default_opts, counter}
  end

  @doc """
  Gets the current count from a counter.
  """
  def get_count(counter), do: :counters.get(counter, 1)
end
