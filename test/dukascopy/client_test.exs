defmodule Dukascopy.ClientTest do
  use ExUnit.Case, async: true

  alias Dukascopy.Client
  alias Dukascopy.TestFixtures
  alias Dukascopy.TestStubs

  ## Tests

  describe "fetch/2 basic behavior" do
    test "returns decompressed LZMA data" do
      opts = TestFixtures.stub_dukascopy(:fetch_lzma)

      # EURUSD/2019/01/04/00h_ticks.bi5 exists in fixtures (month 01 = February, 0-indexed)
      assert {:ok, data} = Client.fetch("EURUSD/2019/01/04/00h_ticks.bi5", opts)
      assert is_binary(data)
      assert byte_size(data) > 0
    end

    test "returns empty binary on 404" do
      opts = TestStubs.fixed_stub(:fetch_404, 404)

      assert {:ok, <<>>} = Client.fetch("nonexistent/path.bi5", opts)
    end

    test "returns error on non-200 status" do
      opts = TestStubs.fixed_stub(:fetch_500, 500)
      opts = Keyword.merge(opts, max_retries: 0)

      assert {:error, {:http_error, 500}} = Client.fetch("some/path.bi5", opts)
    end

    test "returns error on 503" do
      opts = TestStubs.fixed_stub(:fetch_503, 503)
      opts = Keyword.merge(opts, max_retries: 0)

      assert {:error, {:http_error, 503}} = Client.fetch("some/path.bi5", opts)
    end
  end

  describe "LZMA decompression" do
    test "handles empty HTTP body without error" do
      opts = TestStubs.fixed_stub(:lzma_empty, 200, "")

      assert {:ok, <<>>} = Client.fetch("empty.bi5", opts)
    end

    test "handles empty.bi5 fixture (valid LZMA with no data)" do
      opts = TestFixtures.stub_dukascopy(:lzma_empty_fixture)

      assert {:ok, <<>>} = Client.fetch("empty.bi5", opts)
    end

    test "returns error on invalid LZMA data" do
      opts = TestStubs.fixed_stub(:lzma_invalid, 200, "not valid lzma data")

      # Use max_retries: 0 to avoid retry delays
      opts = Keyword.merge(opts, max_retries: 0)

      assert {:error, %RuntimeError{message: msg}} = Client.fetch("invalid.bi5", opts)
      assert msg =~ "LZMA decompression failed"
    end
  end
end
