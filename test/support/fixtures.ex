defmodule DukascopyEx.TestFixtures do
  @moduledoc false

  @fixtures_path "test/fixtures"

  ## Public API

  def fixtures_path(), do: @fixtures_path

  def fixture_path(path), do: Path.join(@fixtures_path, path)

  def read_fixture(path), do: File.read(fixture_path(path))
  def read_fixture!(path), do: File.read!(fixture_path(path))

  @doc """
  Creates a Req.Test stub that serves fixtures based on the request path.

  The stub maps `/datafeed/INSTRUMENT/...` paths to fixture files.
  Returns 404 for paths that don't have a corresponding fixture.
  """
  def stub_dukascopy(name \\ __MODULE__) do
    Req.Test.stub(name, fn conn ->
      fixture_file = path_to_fixture(conn.request_path)

      case read_fixture(fixture_file) do
        {:ok, data} -> Plug.Conn.send_resp(conn, 200, data)
        {:error, :enoent} -> Plug.Conn.send_resp(conn, 404, "")
      end
    end)

    [plug: {Req.Test, name}, retry_log_level: false, retry_delay: 0]
  end

  ## Private functions

  defp path_to_fixture("/datafeed/" <> rest), do: rest
  defp path_to_fixture(path), do: path
end
