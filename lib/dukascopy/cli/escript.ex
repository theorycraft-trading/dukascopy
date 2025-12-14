defmodule Dukascopy.CLI.Escript do
  @moduledoc false

  import Record
  defrecord(:zip_file, extract(:zip_file, from_lib: "stdlib/include/zip.hrl"))

  ## Public API

  @doc """
  Extracts priv files from the escript archive.
  Must be called at the very beginning of main/1, before any code that uses NIFs.
  """
  def extract_priv!() do
    archive_dir = Path.join(System.tmp_dir!(), "dukascopy-escript")
    extracted_marker = Path.join(archive_dir, ".extracted")

    if not File.exists?(extracted_marker) do
      File.mkdir_p!(archive_dir)

      {:ok, sections} = :escript.extract(:escript.script_name(), [])
      archive = Keyword.fetch!(sections, :archive)

      file_filter = fn zip_file(name: name) ->
        List.starts_with?(name, ~c"lzma/")
      end

      opts = [cwd: String.to_charlist(archive_dir), file_filter: file_filter]

      with {:error, error} <- :zip.extract(archive, opts) do
        raise "Failed to extract escript archive: #{inspect(error)}"
      end

      File.touch!(extracted_marker)
    end

    lzma_path = Path.join(archive_dir, "lzma")
    lzma_ebin = Path.join(lzma_path, "ebin")
    :code.add_patha(String.to_charlist(lzma_ebin))
    :code.replace_path(:lzma, String.to_charlist(lzma_path))

    :ok
  end
end
