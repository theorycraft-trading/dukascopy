defmodule Dukascopy.CLI do
  @moduledoc false

  alias Dukascopy.CLI.{Escript, Formatter, Options, Printer}

  ## Public API

  def main(argv) do
    {:ok, _} = Application.ensure_all_started(:elixir)

    :ok = Escript.extract_priv!()
    {:ok, _} = Application.ensure_all_started(:dukascopy)

    Logger.configure(level: :warning)

    case run(argv) do
      :ok -> :ok
      {:error, _} -> System.halt(1)
    end
  end

  ## Private functions

  defp run(argv) do
    if "--help" in argv or "-h" in argv do
      IO.puts(Options.help_text())
      :ok
    else
      execute(argv)
    end
  end

  defp execute(argv) do
    case Options.parse_and_validate(argv) do
      {:ok, opts} ->
        download(opts)

      {:error, {:invalid_options, invalid}} ->
        errors = Enum.map(invalid, fn {opt, _} -> "Unknown option: #{opt}" end)
        Printer.print_errors("Invalid options:", errors)
        {:error, :invalid_options}

      {:error, %NimbleOptions.ValidationError{} = error} ->
        Printer.print_error(Exception.message(error))
        {:error, :validation_error}
    end
  end

  defp download(opts) do
    start_time = System.monotonic_time(:millisecond)

    if not opts.silent do
      Printer.print_header(opts)
    end

    file_path = Formatter.full_file_path(opts)
    stream = build_stream(opts)

    has_progress =
      case Owl.LiveScreen.start_link([]) do
        {:ok, _} ->
          Owl.ProgressBar.start(
            id: :download,
            label: "Downloading",
            total: 100,
            timer: true
          )

          true

        _ ->
          false
      end

    _ = write_with_progress(stream, file_path, opts, has_progress)

    if has_progress do
      Owl.LiveScreen.await_render()
    end

    end_time = System.monotonic_time(:millisecond)
    duration = end_time - start_time

    file_path
    |> File.stat!()
    |> Map.get(:size)
    |> then(&Printer.print_success(file_path, &1, duration))

    :ok
  end

  defp build_stream(opts) do
    stream_opts = [
      from: opts.from,
      to: opts.to,
      price_type: opts.price_type,
      utc_offset: opts.utc_offset,
      timezone: opts.timezone,
      volume_units: opts.volume_units,
      ignore_flats: opts.ignore_flats,
      batch_size: opts.batch_size,
      pause_between_batches_ms: opts.pause_between_batches_ms,
      use_cache: opts.use_cache,
      cache_folder_path: opts.cache_folder_path,
      max_retries: opts.max_retries,
      retry_delay: opts.retry_delay,
      retry_on_empty: opts.retry_on_empty,
      fail_after_retry_count: opts.fail_after_retry_count,
      market_open: opts.market_open,
      weekly_open: opts.weekly_open
    ]

    Dukascopy.stream(opts.instrument, opts.timeframe, stream_opts)
  end

  defp write_with_progress(stream, file_path, opts, has_progress) do
    file_path
    |> Path.dirname()
    |> File.mkdir_p!()

    file = File.open!(file_path, [:write, :utf8])

    case opts.format do
      :csv -> write_csv_with_progress(file, stream, opts, has_progress)
      :json -> write_json_with_progress(file, stream, opts, has_progress)
      :ndjson -> write_ndjson_with_progress(file, stream, opts, has_progress)
    end

    File.close(file)
  end

  defp write_csv_with_progress(file, stream, opts, has_progress) do
    IO.puts(file, Formatter.csv_header(opts.timeframe))

    stream
    |> maybe_with_progress(opts, has_progress)
    |> Enum.each(&IO.puts(file, Formatter.to_csv(&1)))
  end

  defp write_json_with_progress(file, stream, opts, has_progress) do
    IO.puts(file, "[")

    stream
    |> maybe_with_progress(opts, has_progress)
    |> Stream.with_index()
    |> Enum.each(fn {item, index} ->
      prefix = if index == 0, do: "  ", else: ",\n  "
      IO.write(file, prefix <> Formatter.to_json(item))
    end)

    IO.puts(file, "\n]")
  end

  defp write_ndjson_with_progress(file, stream, opts, has_progress) do
    stream
    |> maybe_with_progress(opts, has_progress)
    |> Enum.each(&IO.puts(file, Formatter.to_json(&1)))
  end

  defp maybe_with_progress(stream, opts, true) do
    total_days = Date.diff(opts.to, opts.from)
    Process.put(:last_pct, 0)

    Stream.each(stream, fn item ->
      bar_date = DateTime.to_date(item.time)
      current_pct = min(trunc(Date.diff(bar_date, opts.from) / total_days * 100), 100)
      last_pct = Process.get(:last_pct)

      if current_pct > last_pct do
        Owl.ProgressBar.inc(id: :download, step: current_pct - last_pct)
        Process.put(:last_pct, current_pct)
      end
    end)
  end

  defp maybe_with_progress(stream, _opts, false), do: stream
end
