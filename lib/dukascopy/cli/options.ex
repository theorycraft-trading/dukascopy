defmodule Dukascopy.CLI.Options do
  @moduledoc false

  @schema [
    instrument: [
      type: :string,
      required: true,
      doc: "Trading instrument (e.g., EUR/USD, AAPL.US/USD)"
    ],
    from: [
      type: :string,
      required: true,
      doc: "Start date (YYYY-MM-DD)"
    ],
    to: [
      type: :string,
      default: "now",
      doc: "End date (YYYY-MM-DD or 'now')"
    ],
    timeframe: [
      type: :string,
      default: "D",
      doc: "Timeframe (tick, m1, m5, m15, m30, h1, h4, D, W, M)"
    ],
    price_type: [
      type: {:in, ["bid", "ask", "mid"]},
      default: "bid",
      doc: "Price type"
    ],
    utc_offset: [
      type: :integer,
      default: 0,
      doc: "UTC offset in minutes"
    ],
    timezone: [
      type: :string,
      default: "Etc/UTC",
      doc: "Timezone (e.g., America/New_York)"
    ],
    volume_units: [
      type: {:in, ["millions", "thousands", "units"]},
      default: "millions",
      doc: "Volume units"
    ],
    flats: [
      type: :boolean,
      default: false,
      doc: "Include flat (zero-volume) bars"
    ],
    format: [
      type: {:in, ["csv", "json", "ndjson"]},
      default: "csv",
      doc: "Output format"
    ],
    output: [
      type: :string,
      default: "./download",
      doc: "Output directory"
    ],
    batch_size: [
      type: :pos_integer,
      default: 10,
      doc: "Batch size for parallel downloads"
    ],
    batch_pause: [
      type: :non_neg_integer,
      default: 1000,
      doc: "Pause between batches in ms"
    ],
    cache: [
      type: :boolean,
      default: false,
      doc: "Enable file caching"
    ],
    cache_path: [
      type: :string,
      default: ".dukascopy-cache",
      doc: "Cache folder path"
    ],
    retries: [
      type: :non_neg_integer,
      default: 3,
      doc: "Number of retries per request"
    ],
    retry_pause: [
      type: :non_neg_integer,
      default: 500,
      doc: "Pause between retries in ms"
    ],
    retry_on_empty: [
      type: :boolean,
      default: false,
      doc: "Retry on empty response"
    ],
    fail_after_retries: [
      type: :boolean,
      default: true,
      doc: "Fail after all retries exhausted"
    ],
    market_open: [
      type: :string,
      default: "00:00:00",
      doc: "Market open time (HH:MM:SS)"
    ],
    weekly_open: [
      type: {:in, ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]},
      default: "monday",
      doc: "Weekly open day"
    ],
    silent: [
      type: :boolean,
      default: false,
      doc: "Silent mode (no header output)"
    ],
    filename: [
      type: :string,
      doc: "Custom output filename (without extension)"
    ]
  ]

  @cli_options [
    strict: [
      instrument: :string,
      from: :string,
      to: :string,
      timeframe: :string,
      price_type: :string,
      utc_offset: :integer,
      timezone: :string,
      volume_units: :string,
      flats: :boolean,
      format: :string,
      output: :string,
      batch_size: :integer,
      batch_pause: :integer,
      cache: :boolean,
      cache_path: :string,
      retries: :integer,
      retry_pause: :integer,
      retry_on_empty: :boolean,
      fail_after_retries: :boolean,
      market_open: :string,
      weekly_open: :string,
      silent: :boolean,
      filename: :string,
      help: :boolean
    ],
    aliases: [
      i: :instrument,
      t: :timeframe,
      p: :price_type,
      v: :volume_units,
      f: :format,
      o: :output,
      s: :silent,
      h: :help
    ]
  ]

  ## Public API

  def schema(), do: @schema

  def parse(argv) do
    {opts, _args, invalid} = OptionParser.parse(argv, @cli_options)

    case invalid do
      [] -> {:ok, opts}
      _ -> {:error, {:invalid_options, invalid}}
    end
  end

  def validate(opts) do
    NimbleOptions.validate(opts, @schema)
  end

  def parse_and_validate(argv) do
    with {:ok, parsed} <- parse(argv),
         {:ok, validated} <- validate(parsed) do
      {:ok, to_stream_opts(validated)}
    end
  end

  def help_text() do
    """
    Dukascopy - Download historical market data

    Usage:
      dukascopy download -i INSTRUMENT --from DATE [options]
      dukascopy search <query>

    Commands:
      download            Download historical data
      search <query>      Search for instruments by name

    Required:
      -i, --instrument    Trading instrument (e.g., EUR/USD, AAPL.US/USD)
      --from              Start date (YYYY-MM-DD)

    Date options:
      --to                End date (YYYY-MM-DD or 'now') [default: now]

    Data options:
      -t, --timeframe     Timeframe: tick, m1, m5, m15, m30, h1, h4, D, W, M [default: D]
      -p, --price-type    Price type: bid, ask, mid [default: bid]
      --utc-offset        UTC offset in minutes [default: 0]
      --timezone          Timezone (e.g., America/New_York) [default: Etc/UTC]
      -v, --volume-units  Volume units: millions, thousands, units [default: millions]
      --flats             Include flat (zero-volume) bars [default: false]

    Output options:
      -f, --format        Output format: csv, json, ndjson [default: csv]
      -o, --output        Output directory [default: ./download]
      --filename          Custom filename (without extension)

    Network options:
      --batch-size        Parallel downloads per batch [default: 10]
      --batch-pause       Pause between batches in ms [default: 1000]
      --cache             Enable file caching [default: false]
      --cache-path        Cache folder path [default: .dukascopy-cache]
      --retries           Number of retries per request [default: 3]
      --retry-pause       Pause between retries in ms [default: 500]
      --retry-on-empty    Retry on empty response [default: false]
      --no-fail-after-retries  Don't fail after all retries

    Aggregation options:
      --market-open       Market open time (HH:MM:SS) [default: 00:00:00]
      --weekly-open       Weekly open day [default: monday]

    Other options:
      -s, --silent        Silent mode (no header output)
      -h, --help          Show this help message

    Examples:
      dukascopy download -i EUR/USD --from 2024-01-01 --to 2024-01-31
      dukascopy download -i EUR/USD -t m5 --from 2024-01-01 -f json
      dukascopy search EUR
    """
  end

  ## Private functions

  defp to_stream_opts(opts) do
    %{
      instrument: opts[:instrument],
      timeframe: parse_timeframe(opts[:timeframe]),
      from: parse_date(opts[:from]),
      to: parse_date(opts[:to]),
      price_type: String.to_atom(opts[:price_type]),
      utc_offset: minutes_to_time(opts[:utc_offset]),
      timezone: opts[:timezone],
      volume_units: String.to_atom(opts[:volume_units]),
      ignore_flats: not opts[:flats],
      format: String.to_atom(opts[:format]),
      output: opts[:output],
      batch_size: opts[:batch_size],
      pause_between_batches_ms: opts[:batch_pause],
      use_cache: opts[:cache],
      cache_folder_path: opts[:cache_path],
      max_retries: opts[:retries],
      retry_delay: opts[:retry_pause],
      retry_on_empty: opts[:retry_on_empty],
      fail_after_retry_count: opts[:fail_after_retries],
      market_open: parse_time(opts[:market_open]),
      weekly_open: String.to_atom(opts[:weekly_open]),
      silent: opts[:silent],
      filename: opts[:filename]
    }
  end

  defp parse_timeframe("tick"), do: :tick
  defp parse_timeframe(tf), do: tf

  defp parse_date("now"), do: Date.utc_today()

  defp parse_date(date_str) do
    case Date.from_iso8601(date_str) do
      {:ok, date} -> date
      {:error, _} -> raise ArgumentError, "Invalid date format: #{date_str}. Use YYYY-MM-DD"
    end
  end

  defp parse_time(time_str) do
    case Time.from_iso8601(time_str) do
      {:ok, time} -> time
      {:error, _} -> raise ArgumentError, "Invalid time format: #{time_str}. Use HH:MM:SS"
    end
  end

  defp minutes_to_time(minutes) when is_integer(minutes) do
    hours = div(abs(minutes), 60)
    mins = rem(abs(minutes), 60)
    Time.new!(hours, mins, 0)
  end
end
