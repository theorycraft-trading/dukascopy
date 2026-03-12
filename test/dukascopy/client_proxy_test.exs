defmodule Dukascopy.ClientProxyTest do
  use ExUnit.Case, async: true

  alias Dukascopy.Client

  ## Tests

  describe "proxy URL parsing" do
    test "parses HTTP proxy URL without auth" do
      # We can't easily test the actual proxy connection without a proxy server,
      # but we can verify the option is accepted and doesn't raise
      opts = [plug: {Req.Test, :proxy_http}, max_retries: 0]

      Req.Test.stub(:proxy_http, fn conn ->
        Req.Test.json(conn, %{})
      end)

      # Should not raise when proxy option is provided
      assert {:error, _} =
               Client.fetch("test.bi5", Keyword.put(opts, :proxy, "http://localhost:8080"))
    end

    test "parses HTTPS proxy URL without auth" do
      opts = [plug: {Req.Test, :proxy_https}, max_retries: 0]

      Req.Test.stub(:proxy_https, fn conn ->
        Req.Test.json(conn, %{})
      end)

      # Should not raise when proxy option is provided
      assert {:error, _} =
               Client.fetch("test.bi5", Keyword.put(opts, :proxy, "https://localhost:8080"))
    end

    test "parses SOCKS5 proxy URL" do
      opts = [plug: {Req.Test, :proxy_socks5}, max_retries: 0]

      Req.Test.stub(:proxy_socks5, fn conn ->
        Req.Test.json(conn, %{})
      end)

      # Should not raise when proxy option is provided
      assert {:error, _} =
               Client.fetch("test.bi5", Keyword.put(opts, :proxy, "socks5://localhost:1080"))
    end

    test "parses HTTP proxy URL with authentication" do
      opts = [plug: {Req.Test, :proxy_auth}, max_retries: 0]

      Req.Test.stub(:proxy_auth, fn conn ->
        Req.Test.json(conn, %{})
      end)

      # Should not raise when proxy with auth is provided
      assert {:error, _} =
               Client.fetch(
                 "test.bi5",
                 Keyword.put(opts, :proxy, "http://user:pass@localhost:8080")
               )
    end

    test "raises on unsupported proxy scheme" do
      opts = [plug: {Req.Test, :proxy_invalid}, max_retries: 0]

      Req.Test.stub(:proxy_invalid, fn conn ->
        Req.Test.json(conn, %{})
      end)

      assert_raise ArgumentError, ~r/Unsupported proxy scheme/, fn ->
        Client.fetch("test.bi5", Keyword.put(opts, :proxy, "ftp://localhost:21"))
      end
    end

    test "works without proxy (nil)" do
      opts = [plug: {Req.Test, :no_proxy}, max_retries: 0]

      Req.Test.stub(:no_proxy, fn conn ->
        Req.Test.json(conn, %{})
      end)

      # Should not raise when no proxy
      assert {:error, _} = Client.fetch("test.bi5", Keyword.put(opts, :proxy, nil))
    end
  end
end
