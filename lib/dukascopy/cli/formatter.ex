defmodule Dukascopy.CLI.Formatter do
  @moduledoc false

  alias TheoryCraft.MarketSource.{Bar, Tick}

  ## Public API

  def csv_header(:ticks), do: "timestamp,ask,bid,ask_volume,bid_volume"
  def csv_header(_timeframe), do: "timestamp,open,high,low,close,volume"

  def to_csv(%Tick{} = tick) do
    [
      DateTime.to_iso8601(tick.time),
      ",",
      Float.to_string(tick.ask),
      ",",
      Float.to_string(tick.bid),
      ",",
      format_volume(tick.ask_volume),
      ",",
      format_volume(tick.bid_volume)
    ]
  end

  def to_csv(%Bar{} = bar) do
    [
      DateTime.to_iso8601(bar.time),
      ",",
      Float.to_string(bar.open),
      ",",
      Float.to_string(bar.high),
      ",",
      Float.to_string(bar.low),
      ",",
      Float.to_string(bar.close),
      ",",
      format_volume(bar.volume)
    ]
  end

  def to_json(%Tick{} = tick) do
    JSON.encode!(%{
      timestamp: DateTime.to_iso8601(tick.time),
      ask: tick.ask,
      bid: tick.bid,
      ask_volume: tick.ask_volume,
      bid_volume: tick.bid_volume
    })
  end

  def to_json(%Bar{} = bar) do
    JSON.encode!(%{
      timestamp: DateTime.to_iso8601(bar.time),
      open: bar.open,
      high: bar.high,
      low: bar.low,
      close: bar.close,
      volume: bar.volume
    })
  end

  def full_file_path(opts) do
    filename = generate_filename(opts)
    extension = to_string(opts.format)
    Path.join(opts.output, "#{filename}.#{extension}")
  end

  ## Private functions

  defp generate_filename(opts) do
    case opts.filename do
      nil -> auto_filename(opts)
      custom -> custom
    end
  end

  defp auto_filename(opts) do
    instrument = String.replace(opts.instrument, "/", "")
    timeframe = to_string(opts.timeframe)
    price_type = to_string(opts.price_type)
    from_str = Date.to_iso8601(opts.from)
    to_str = Date.to_iso8601(opts.to)

    "#{instrument}-#{timeframe}-#{price_type}-#{from_str}-#{to_str}"
  end

  defp format_volume(nil), do: ""
  defp format_volume(v) when is_float(v), do: Float.to_string(v)
  defp format_volume(v) when is_integer(v), do: Integer.to_string(v)
end
