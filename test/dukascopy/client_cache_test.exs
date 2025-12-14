defmodule Dukascopy.ClientCacheTest do
  use ExUnit.Case, async: true

  alias Dukascopy.Client
  alias Dukascopy.TestFixtures
  alias Dukascopy.TestStubs

  @valid_fixture TestFixtures.read_fixture!("EURUSD/2019/01/04/00h_ticks.bi5")

  ## Setup

  setup do
    # Create a unique temp cache folder for each test
    cache_path = Path.join(System.tmp_dir!(), "dukascopy_test_#{:rand.uniform(1_000_000)}")
    on_exit(fn -> File.rm_rf!(cache_path) end)
    {:ok, cache_path: cache_path}
  end

  ## Tests

  describe "use_cache option" do
    test "writes to disk after fetch", %{cache_path: cache_path} do
      {opts, _counter} = TestStubs.counting_fixed_stub(:cache_write, 200, @valid_fixture)

      opts = Keyword.merge(opts, use_cache: true, cache_folder_path: cache_path)

      assert {:ok, _data} = Client.fetch("EURUSD/2019/01/04/00h_ticks.bi5", opts)

      # Check cache file was created
      cache_file = Path.join(cache_path, "EURUSD-2019-01-04-00h_ticks.bi5")
      assert File.exists?(cache_file)
    end

    test "reads from cache on second fetch", %{cache_path: cache_path} do
      {opts, counter} = TestStubs.counting_fixed_stub(:cache_read, 200, @valid_fixture)

      opts = Keyword.merge(opts, use_cache: true, cache_folder_path: cache_path)

      # First fetch - hits network
      assert {:ok, data1} = Client.fetch("EURUSD/2019/01/04/00h_ticks.bi5", opts)
      assert TestStubs.get_count(counter) == 1

      # Second fetch - should use cache, not network
      assert {:ok, data2} = Client.fetch("EURUSD/2019/01/04/00h_ticks.bi5", opts)
      assert TestStubs.get_count(counter) == 1

      # Data should be the same
      assert data1 == data2
    end

    test "does not cache 404 responses", %{cache_path: cache_path} do
      {opts, _counter} = TestStubs.counting_fixed_stub(:cache_404, 404)

      opts = Keyword.merge(opts, use_cache: true, cache_folder_path: cache_path)

      assert {:ok, <<>>} = Client.fetch("nonexistent.bi5", opts)

      # No cache file should be created
      cache_file = Path.join(cache_path, "nonexistent.bi5")
      refute File.exists?(cache_file)
    end

    test "does not cache empty responses", %{cache_path: cache_path} do
      {opts, _counter} = TestStubs.counting_fixed_stub(:cache_empty, 200, "")

      opts = Keyword.merge(opts, use_cache: true, cache_folder_path: cache_path)

      assert {:ok, <<>>} = Client.fetch("empty.bi5", opts)

      # No cache file should be created for empty response
      cache_file = Path.join(cache_path, "empty.bi5")
      refute File.exists?(cache_file)
    end

    test "does not cache error responses", %{cache_path: cache_path} do
      {opts, _counter} = TestStubs.counting_fixed_stub(:cache_error, 500)

      # max_retries: 0 to avoid delays, fail_after_retry_count: true to get error
      opts =
        Keyword.merge(opts,
          use_cache: true,
          cache_folder_path: cache_path,
          max_retries: 0,
          fail_after_retry_count: true
        )

      assert {:error, {:http_error, 500}} = Client.fetch("error.bi5", opts)

      # No cache file should be created
      cache_file = Path.join(cache_path, "error.bi5")
      refute File.exists?(cache_file)
    end
  end

  describe "cache_folder_path option" do
    test "uses custom cache path", %{cache_path: cache_path} do
      custom_path = Path.join(cache_path, "custom")
      {opts, _counter} = TestStubs.counting_fixed_stub(:cache_custom, 200, @valid_fixture)

      opts = Keyword.merge(opts, use_cache: true, cache_folder_path: custom_path)

      assert {:ok, _data} = Client.fetch("test.bi5", opts)

      # Cache should be in custom path
      assert File.exists?(custom_path)
      assert File.exists?(Path.join(custom_path, "test.bi5"))
    end

    test "creates cache folder if it does not exist", %{cache_path: cache_path} do
      nested_path = Path.join([cache_path, "deep", "nested", "folder"])
      {opts, _counter} = TestStubs.counting_fixed_stub(:cache_nested, 200, @valid_fixture)

      opts = Keyword.merge(opts, use_cache: true, cache_folder_path: nested_path)

      refute File.exists?(nested_path)

      assert {:ok, _data} = Client.fetch("test.bi5", opts)

      assert File.exists?(nested_path)
    end
  end

  describe "cache disabled by default" do
    test "does not write to disk when use_cache is false (default)", %{cache_path: cache_path} do
      {opts, _counter} = TestStubs.counting_fixed_stub(:no_cache, 200, @valid_fixture)

      opts = Keyword.merge(opts, cache_folder_path: cache_path)
      # use_cache defaults to false

      assert {:ok, _data} = Client.fetch("test.bi5", opts)

      # No cache folder should be created
      refute File.exists?(cache_path)
    end
  end
end
