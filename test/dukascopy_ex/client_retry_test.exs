defmodule DukascopyEx.ClientRetryTest do
  use ExUnit.Case, async: true

  alias DukascopyEx.Client
  alias DukascopyEx.TestFixtures
  alias DukascopyEx.TestStubs

  @valid_fixture TestFixtures.read_fixture!("EURUSD/2019/01/04/00h_ticks.bi5")

  ## Public API

  describe "retry on errors" do
    test "retries on 500 status then succeeds" do
      {opts, counter} =
        TestStubs.counting_stub(:retry_500, [
          {500, ""},
          {500, ""},
          {200, @valid_fixture}
        ])

      assert {:ok, data} = Client.fetch("test.bi5", opts)
      assert is_binary(data)
      assert TestStubs.get_count(counter) == 3
    end

    test "retries on 503 status then succeeds" do
      {opts, counter} =
        TestStubs.counting_stub(:retry_503, [
          {503, ""},
          {200, @valid_fixture}
        ])

      assert {:ok, data} = Client.fetch("test.bi5", opts)
      assert is_binary(data)
      assert TestStubs.get_count(counter) == 2
    end

    test "does not retry on 404" do
      {opts, counter} = TestStubs.counting_fixed_stub(:no_retry_404, 404)

      assert {:ok, <<>>} = Client.fetch("test.bi5", opts)
      assert TestStubs.get_count(counter) == 1
    end

    test "does not retry on 200" do
      {opts, counter} = TestStubs.counting_fixed_stub(:no_retry_200, 200, @valid_fixture)

      assert {:ok, _data} = Client.fetch("test.bi5", opts)
      assert TestStubs.get_count(counter) == 1
    end
  end

  describe "retry_on_empty option" do
    test "retries when body is empty and retry_on_empty is true" do
      {opts, counter} =
        TestStubs.counting_stub(:retry_empty, [
          {200, ""},
          {200, ""},
          {200, @valid_fixture}
        ])

      opts = Keyword.merge(opts, retry_on_empty: true)

      assert {:ok, data} = Client.fetch("test.bi5", opts)
      assert is_binary(data)
      assert TestStubs.get_count(counter) == 3
    end

    test "accepts empty body when retry_on_empty is false (default)" do
      {opts, counter} = TestStubs.counting_fixed_stub(:accept_empty, 200, "")

      assert {:ok, <<>>} = Client.fetch("test.bi5", opts)
      assert TestStubs.get_count(counter) == 1
    end
  end

  describe "transport errors" do
    test "retries on timeout" do
      # First call timeouts, second succeeds
      counter = :counters.new(1, [:atomics])

      Req.Test.stub(:retry_timeout, fn conn ->
        idx = :counters.get(counter, 1)
        :counters.add(counter, 1, 1)

        if idx == 0 do
          Req.Test.transport_error(conn, :timeout)
        else
          Plug.Conn.send_resp(conn, 200, @valid_fixture)
        end
      end)

      opts = [
        plug: {Req.Test, :retry_timeout},
        retry_log_level: false,
        retry_delay: 0
      ]

      assert {:ok, data} = Client.fetch("test.bi5", opts)
      assert is_binary(data)
      assert :counters.get(counter, 1) == 2
    end

    test "retries on connection refused" do
      counter = :counters.new(1, [:atomics])

      Req.Test.stub(:retry_econnrefused, fn conn ->
        idx = :counters.get(counter, 1)
        :counters.add(counter, 1, 1)

        if idx == 0 do
          Req.Test.transport_error(conn, :econnrefused)
        else
          Plug.Conn.send_resp(conn, 200, @valid_fixture)
        end
      end)

      opts = [
        plug: {Req.Test, :retry_econnrefused},
        retry_log_level: false,
        retry_delay: 0
      ]

      assert {:ok, data} = Client.fetch("test.bi5", opts)
      assert is_binary(data)
      assert :counters.get(counter, 1) == 2
    end
  end

  describe "max_retries option" do
    test "respects custom max_retries" do
      {opts, counter} =
        TestStubs.counting_stub(:retry_count_2, [
          {500, ""},
          {500, ""},
          {200, @valid_fixture}
        ])

      # With max_retries: 2, should try 3 times (1 initial + 2 retries)
      opts = Keyword.merge(opts, max_retries: 2)

      # Should succeed on 3rd try
      assert {:ok, _data} = Client.fetch("test.bi5", opts)
      assert TestStubs.get_count(counter) == 3
    end

    test "fails after exhausting retries" do
      {opts, counter} = TestStubs.counting_fixed_stub(:exhaust_retries, 500)

      opts = Keyword.merge(opts, max_retries: 2)

      # Should fail after 3 attempts (1 + 2 retries)
      assert {:error, {:http_error, 500}} = Client.fetch("test.bi5", opts)
      assert TestStubs.get_count(counter) == 3
    end
  end

  describe "fail_after_retry_count option" do
    test "returns error when true (default) and retries exhausted" do
      {opts, _counter} = TestStubs.counting_fixed_stub(:fail_true, 500)

      opts = Keyword.merge(opts, max_retries: 1, fail_after_retry_count: true)

      assert {:error, {:http_error, 500}} = Client.fetch("test.bi5", opts)
    end

    test "returns empty binary when false and retries exhausted" do
      {opts, _counter} = TestStubs.counting_fixed_stub(:fail_false, 500)

      opts = Keyword.merge(opts, max_retries: 1, fail_after_retry_count: false)

      assert {:ok, <<>>} = Client.fetch("test.bi5", opts)
    end

    test "returns empty when retry_on_empty exhausted and fail_after is false" do
      {opts, _counter} = TestStubs.counting_fixed_stub(:fail_empty_false, 200, "")

      opts =
        Keyword.merge(opts, max_retries: 1, retry_on_empty: true, fail_after_retry_count: false)

      assert {:ok, <<>>} = Client.fetch("test.bi5", opts)
    end
  end
end
