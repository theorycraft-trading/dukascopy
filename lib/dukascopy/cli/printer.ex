defmodule Dukascopy.CLI.Printer do
  @moduledoc false

  ## Public API

  def print_header(opts) do
    print_divider()
    IO.puts(IO.ANSI.white() <> "Downloading historical price data for:" <> IO.ANSI.reset())
    print_divider()

    print_field("Instrument", opts.instrument)
    print_field("Timeframe", opts.timeframe)
    print_field("From date", Date.to_iso8601(opts.from))
    print_field("To date", Date.to_iso8601(opts.to))

    if opts.timeframe != :ticks do
      print_field("Price type", opts.price_type)
    end

    print_field("Volume units", opts.volume_units)
    print_field("UTC Offset", "#{opts.utc_offset} min")
    print_field("Include flats", not opts.ignore_flats)
    print_field("Format", opts.format)

    print_divider()
  end

  def print_success(file_path, file_size, duration_ms) do
    print_divider()

    message =
      IO.ANSI.green() <>
        IO.ANSI.bright() <>
        "File saved: #{file_path} (#{format_bytes(file_size)})" <>
        IO.ANSI.reset()

    IO.puts(message)
    IO.puts("Download time: #{format_duration(duration_ms)}")
    IO.puts("")
  end

  def print_error(message) do
    IO.puts(:stderr, IO.ANSI.red() <> IO.ANSI.bright() <> "Error: #{message}" <> IO.ANSI.reset())
  end

  def print_errors(header, errors) when is_list(errors) do
    IO.puts(:stderr, IO.ANSI.red() <> IO.ANSI.bright() <> header <> IO.ANSI.reset())

    Enum.each(errors, fn error ->
      IO.puts(:stderr, IO.ANSI.red() <> " > #{error}" <> IO.ANSI.reset())
    end)

    IO.puts("")
  end

  def print_errors(header, error), do: print_errors(header, [error])

  ## Private functions

  defp print_divider do
    IO.puts(IO.ANSI.light_black() <> "----------------------------------------------------" <> IO.ANSI.reset())
  end

  defp print_field(label, value) do
    padded_label = String.pad_trailing("#{label}:", 16)
    formatted_value = IO.ANSI.yellow() <> IO.ANSI.bright() <> to_string(value) <> IO.ANSI.reset()
    IO.puts("#{padded_label}#{formatted_value}")
  end

  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_bytes(bytes) when bytes < 1024 * 1024, do: "#{Float.round(bytes / 1024, 2)} KB"
  defp format_bytes(bytes), do: "#{Float.round(bytes / (1024 * 1024), 2)} MB"

  defp format_duration(ms) when ms < 1000, do: "#{ms}ms"
  defp format_duration(ms) when ms < 60_000, do: "#{Float.round(ms / 1000, 1)}s"

  defp format_duration(ms) do
    seconds = div(ms, 1000)
    minutes = div(seconds, 60)
    remaining_seconds = rem(seconds, 60)
    "#{minutes}m #{remaining_seconds}s"
  end
end
