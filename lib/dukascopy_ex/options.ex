defmodule DukascopyEx.Options do
  @moduledoc false

  # Validates and normalizes options for `DukascopyEx.stream/3`.

  require DukascopyEx.Enums, as: Enums

  alias DukascopyEx.Instruments
  alias TheoryCraft.TimeFrame

  @type validated_opts :: Keyword.t()

  @doc """
  Validates and normalizes options for stream/3.

  Returns `{:ok, validated_opts}` on success or `{:error, reason}` on failure.

  ## Required options

    * `:from` and `:to` - Start and end of the date range (DateTime or Date).
      Uses half-open interval `[from, to)`: from is inclusive, to is exclusive.
    * OR `:date_range` - A `Date.Range` struct. Both ends are inclusive `[first, last]`.

  ## Optional options

    * `:price_type` - `:bid` (default), `:ask`, or `:mid`
    * `:utc_offset` - Fixed UTC offset as Time (default: `~T[00:00:00]`)
    * `:timezone` - Timezone string with DST support (default: `"Etc/UTC"`)
    * `:volume_units` - `:millions` (default), `:thousands`, or `:units`
    * `:ignore_flats` - Ignore zero-volume bars (default: `true`). Does not apply to ticks.
    * `:batch_size` - Parallel requests per batch (default: `10`)
    * `:pause_between_batches_ms` - Pause between batches in ms (default: `1000`)
    * `:use_cache` - Enable file caching (default: `false`)
    * `:cache_folder_path` - Cache folder path (default: `".dukascopy-cache"`)
    * `:max_retries` - Number of retries per request (default: `3`)
    * `:retry_on_empty` - Retry on empty response (default: `false`)
    * `:fail_after_retry_count` - Raise error after all retries (default: `true`)
    * `:retry_delay` - Delay between retries. Can be an integer (fixed ms)
      or a function `(attempt :: integer) -> ms`. Default: exponential backoff `200 * 2^attempt`
    * `:market_open` - Market open time for alignment (default: `~T[00:00:00]`)
    * `:weekly_open` - Week start day (default: `:monday`)

  """
  @spec validate(String.t(), DukascopyEx.timeframe(), Keyword.t()) ::
          {:ok, validated_opts()} | {:error, term()}
  def validate(instrument, timeframe, opts) do
    with :ok <- validate_instrument(instrument),
         :ok <- validate_timeframe(timeframe),
         {:ok, date_range} <- extract_date_range(opts),
         {:ok, merged_opts} <- merge_and_validate_opts(opts) do
      {:ok, Keyword.put(merged_opts, :date_range, date_range)}
    end
  end

  @doc """
  Same as `validate/3` but raises on error.
  """
  @spec validate!(String.t(), DukascopyEx.timeframe(), Keyword.t()) :: validated_opts()
  def validate!(instrument, timeframe, opts) do
    case validate(instrument, timeframe, opts) do
      {:ok, validated_opts} -> validated_opts
      {:error, reason} -> raise ArgumentError, format_error(reason)
    end
  end

  @doc """
  Returns the default options.
  """
  @spec defaults() :: Keyword.t()
  def defaults() do
    [
      price_type: :bid,
      utc_offset: ~T[00:00:00],
      timezone: "Etc/UTC",
      volume_units: :millions,
      ignore_flats: true,
      batch_size: 10,
      pause_between_batches_ms: 1000,
      use_cache: false,
      cache_folder_path: ".dukascopy-cache",
      max_retries: 3,
      retry_on_empty: false,
      fail_after_retry_count: true,
      # Default exponential backoff: 200ms, 400ms, 800ms, 1600ms...
      retry_delay: &trunc(200 * :math.pow(2, &1)),
      market_open: ~T[00:00:00],
      weekly_open: :monday
    ]
  end

  @doc """
  Returns the default options for DataFeed.

  Inherits all options from `defaults/0` and adds:

    * `:granularity` - `:ticks` (default)
    * `:halt_on_error` - `true` (default) - whether to crash on fetch errors

  """
  @spec feed_defaults() :: Keyword.t()
  def feed_defaults() do
    Keyword.merge(defaults(), granularity: :ticks, halt_on_error: true)
  end

  @doc """
  Validates options for DataFeed.stream/1.

  Returns `{:ok, validated_opts}` on success or `{:error, reason}` on failure.

  Inherits all options from `validate/3` and adds DataFeed-specific options.

  ## Required options

    * `:instrument` - Trading instrument (e.g., "EUR/USD")
    * `:from` and `:to` - Date range (DateTime or Date). Half-open interval `[from, to)`
    * OR `:date_range` - A `Date.Range` struct (inclusive)

  ## DataFeed-specific options

    * `:granularity` - `:ticks` (default), `:minute`, `:hour`, or `:day`
    * `:halt_on_error` - Whether to crash on fetch errors (default: `true`)

  ## Inherited options (from `defaults/0`)

    * `:price_type` - `:bid` (default), `:ask`, or `:mid`
      Note: `:mid` for bars fetches both bid and ask data (2x HTTP requests)
    * `:batch_size` - Parallel requests per batch (default: `10`)
    * `:pause_between_batches_ms` - Pause between batches in ms (default: `1000`)
    * `:max_retries` - Number of retries per request (default: `3`)
    * `:retry_delay` - Delay between retries (default: exponential backoff)
    * `:retry_on_empty` - Retry on empty response (default: `false`)
    * `:fail_after_retry_count` - Return error after all retries (default: `true`)
    * `:use_cache` - Enable file caching (default: `false`)
    * `:cache_folder_path` - Cache folder path (default: `".dukascopy-cache"`)
    * `:ignore_flats` - Ignore zero-volume bars (default: `true`). Does not apply to ticks.
    * `:market_open` - Market open time for alignment (default: `~T[00:00:00]`)
    * `:weekly_open` - Week start day (default: `:monday`)

  """
  @spec validate_feed(Keyword.t()) :: {:ok, validated_opts()} | {:error, term()}
  def validate_feed(opts) do
    merged = Keyword.merge(feed_defaults(), opts)

    with {:ok, instrument} <- extract_instrument(merged),
         {:ok, date_range} <- extract_date_range(merged),
         {:ok, granularity} <- extract_granularity(merged),
         {:ok, price_type} <- extract_feed_price_type(merged),
         {:ok, common_validated} <- validate_common_opts(merged) do
      result =
        Keyword.merge(common_validated,
          instrument: instrument,
          date_range: date_range,
          granularity: granularity,
          price_type: price_type
        )

      {:ok, result}
    end
  end

  ## Private functions

  defp extract_instrument(opts) do
    case Keyword.get(opts, :instrument) do
      nil -> {:error, :missing_instrument}
      instrument -> validate_instrument_value(instrument)
    end
  end

  defp validate_instrument_value(instrument) do
    case Instruments.get_historical_filename(instrument) do
      nil -> {:error, {:unknown_instrument, instrument}}
      _ -> {:ok, instrument}
    end
  end

  defp validate_instrument(instrument) do
    case Instruments.get_historical_filename(instrument) do
      nil -> {:error, {:unknown_instrument, instrument}}
      _ -> :ok
    end
  end

  defp extract_granularity(opts) do
    case Keyword.get(opts, :granularity) do
      value when value in Enums.granularity(:__keys__) -> {:ok, value}
      value -> {:error, {:invalid_granularity, value}}
    end
  end

  defp extract_feed_price_type(opts) do
    case Keyword.get(opts, :price_type) do
      value when value in [:bid, :ask, :mid] -> {:ok, value}
      value -> {:error, {:invalid_price_type, value}}
    end
  end

  defp validate_timeframe(:ticks), do: :ok

  defp validate_timeframe(tf) do
    case TimeFrame.valid?(tf) do
      true -> :ok
      false -> {:error, {:invalid_timeframe, tf}}
    end
  end

  defp extract_date_range(opts) do
    date_range = Keyword.get(opts, :date_range)

    case date_range do
      {%DateTime{}, %DateTime{}} = range -> {:ok, range}
      _ -> extract_date_range_from_opts(opts, date_range)
    end
  end

  defp extract_date_range_from_opts(opts, date_range) do
    from = Keyword.get(opts, :from)
    to = Keyword.get(opts, :to)

    case {from, to, date_range} do
      {nil, nil, nil} ->
        {:error, :missing_date_range}

      {nil, nil, %Date.Range{} = range} ->
        {:ok, date_range_to_datetimes(range)}

      {from, to, nil} when not is_nil(from) and not is_nil(to) ->
        {:ok, {normalize_datetime(from), normalize_datetime(to)}}

      {_, _, %Date.Range{}} ->
        {:error, :conflicting_date_options}

      {_, _, _} ->
        {:error, :partial_date_range}
    end
  end

  defp normalize_datetime(%DateTime{} = dt), do: dt
  defp normalize_datetime(%Date{} = d), do: DateTime.new!(d, ~T[00:00:00], "Etc/UTC")

  defp date_range_to_datetimes(%Date.Range{first: first, last: last}) do
    from = normalize_datetime(first)
    # Add 1 day to include the last day in the range
    to = normalize_datetime(Date.add(last, 1))
    {from, to}
  end

  defp merge_and_validate_opts(opts) do
    merged = Keyword.merge(defaults(), opts)

    with {:ok, price_type} <- extract_price_type(merged),
         {:ok, volume_units} <- extract_volume_units(merged),
         {:ok, utc_offset} <- extract_utc_offset(merged),
         {:ok, weekly_open} <- extract_weekly_open(merged),
         {:ok, common_validated} <- validate_common_opts(merged) do
      result =
        Keyword.merge(
          common_validated,
          price_type: price_type,
          volume_units: volume_units,
          utc_offset: utc_offset,
          weekly_open: weekly_open
        )

      {:ok, result}
    end
  end

  # Validates options common to both validate/3 and validate_feed/1
  defp validate_common_opts(opts) do
    with {:ok, batch_size} <- extract_positive_integer(opts, :batch_size),
         {:ok, pause_batches} <- extract_non_negative_integer(opts, :pause_between_batches_ms),
         {:ok, max_retries} <- extract_non_negative_integer(opts, :max_retries),
         {:ok, retry_delay} <- extract_retry_delay(opts) do
      result =
        Keyword.merge(
          opts,
          batch_size: batch_size,
          pause_between_batches_ms: pause_batches,
          max_retries: max_retries,
          retry_delay: retry_delay
        )

      {:ok, result}
    end
  end

  defp extract_price_type(opts) do
    case Keyword.get(opts, :price_type) do
      value when value in Enums.price_type(:__keys__) -> {:ok, value}
      value -> {:error, {:invalid_price_type, value}}
    end
  end

  defp extract_volume_units(opts) do
    case Keyword.get(opts, :volume_units) do
      value when value in Enums.volume_units(:__keys__) -> {:ok, value}
      value -> {:error, {:invalid_volume_units, value}}
    end
  end

  defp extract_utc_offset(opts) do
    case Keyword.get(opts, :utc_offset) do
      %Time{} = t -> {:ok, t}
      other -> {:error, {:invalid_utc_offset, other}}
    end
  end

  defp extract_weekly_open(opts) do
    case Keyword.get(opts, :weekly_open) do
      value when value in Enums.weekly_open(:__keys__) -> {:ok, value}
      value -> {:error, {:invalid_weekly_open, value}}
    end
  end

  defp extract_positive_integer(opts, key) do
    case Keyword.get(opts, key) do
      n when is_integer(n) and n > 0 -> {:ok, n}
      n -> {:error, {:invalid_positive_integer, key, n}}
    end
  end

  defp extract_non_negative_integer(opts, key) do
    case Keyword.get(opts, key) do
      n when is_integer(n) and n >= 0 -> {:ok, n}
      n -> {:error, {:invalid_non_negative_integer, key, n}}
    end
  end

  defp extract_retry_delay(opts) do
    case Keyword.get(opts, :retry_delay) do
      n when is_integer(n) and n >= 0 -> {:ok, n}
      f when is_function(f, 1) -> {:ok, f}
      other -> {:error, {:invalid_retry_delay, other}}
    end
  end

  @error_messages %{
    missing_instrument: "Missing instrument. Provide :instrument option",
    missing_date_range: "Missing date range. Provide :from and :to, or :date_range",
    partial_date_range: "Partial date range. Provide both :from and :to",
    conflicting_date_options: "Conflicting date options. Use :from/:to OR :date_range, not both"
  }

  @error_templates %{
    unknown_instrument: {"Unknown instrument: ~s", []},
    invalid_timeframe:
      {"Invalid timeframe: ~s. Use :ticks or a TheoryCraft timeframe string (e.g., \"m5\", \"h1\", \"D\")",
       []},
    invalid_granularity: {"Invalid granularity: ~s. Use :ticks, :minute, :hour, or :day", []},
    invalid_price_type: {"Invalid price_type: ~s. Use :bid, :ask, or :mid", []},
    invalid_volume_units: {"Invalid volume_units: ~s. Use :millions, :thousands, or :units", []},
    invalid_utc_offset: {"Invalid utc_offset: ~s. Use a Time struct (e.g., ~T[02:30:00])", []},
    invalid_weekly_open: {"Invalid weekly_open: ~s. Use :monday, :tuesday, etc.", []},
    invalid_positive_integer: {"Invalid ~s: ~s. Must be a positive integer", []},
    invalid_non_negative_integer: {"Invalid ~s: ~s. Must be a non-negative integer", []},
    invalid_retry_delay:
      {"Invalid retry_delay: ~s. Must be a non-negative integer or a function/1", []}
  }

  defp format_error(error) when is_atom(error) do
    Map.get(@error_messages, error, "Error: #{inspect(error)}")
  end

  defp format_error({type, value}) do
    case Map.get(@error_templates, type) do
      {template, _} -> :io_lib.format(template, [inspect(value)]) |> to_string()
      nil -> "Error: #{inspect({type, value})}"
    end
  end

  defp format_error({type, key, value}) do
    case Map.get(@error_templates, type) do
      {template, _} -> :io_lib.format(template, [key, inspect(value)]) |> to_string()
      nil -> "Error: #{inspect({type, key, value})}"
    end
  end

  defp format_error(other), do: "Error: #{inspect(other)}"
end
