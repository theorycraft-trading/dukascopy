defmodule Dukascopy do
  @moduledoc """
  Elixir client for downloading historical market data from Dukascopy Bank SA.

  Supports 1600+ instruments including Forex, Stocks, Crypto, Commodities, Bonds, ETFs, and Indices.

  ## Usage

  The main function is `stream/3` which returns a lazy stream of market data:

      # Stream raw ticks
      iex> Dukascopy.stream("EUR/USD", :ticks, from: ~D[2024-01-01], to: ~D[2024-01-02])
      ...> |> Enum.take(100)

      # Stream 5-minute bars
      iex> Dukascopy.stream("EUR/USD", :m5, from: ~D[2024-01-01], to: ~D[2024-01-31])
      ...> |> Enum.to_list()

      # Stream hourly bars with options
      iex> Dukascopy.stream("EUR/USD", :h1,
      ...>   from: ~D[2024-01-01],
      ...>   to: ~D[2024-12-31],
      ...>   price_type: :mid,
      ...>   timezone: "America/New_York"
      ...> )

  ## Supported Timeframes

  Timeframes can be specified as strings or atoms (e.g., `"m5"` or `:m5`).

    - `:ticks` - Raw tick data
    - `t<N>` - N ticks per bar (e.g., `:t5`)
    - `s<N>` - N-second bars (e.g., `:s30`)
    - `m<N>` - N-minute bars (e.g., `:m1`, `:m5`, `:m15`)
    - `h<N>` - N-hour bars (e.g., `:h1`, `:h4`)
    - `D<N>` - N-day bars (e.g., `:D`, `:D3`)
    - `W<N>` - N-week bars (e.g., `:W`)
    - `M<N>` - N-month bars (e.g., `:M`)

  """

  alias Dukascopy.{DataFeed, Options}
  alias TheoryCraft.{MarketSource, TimeFrame}
  alias TheoryCraft.MarketSource.MarketEvent

  @type timeframe :: :ticks | atom() | String.t()

  @doc """
  Creates a lazy stream of ticks or bars for an instrument and time period.

  ## Parameters

    * `instrument` - Trading instrument (e.g., "EUR/USD", "AAPL.US/USD")
    * `timeframe` - Target timeframe: `:ticks` or a TheoryCraft timeframe (atom or string)
    * `opts` - Options keyword list (see below)

  ## Required Options

    * `:from` and `:to` - Start and end of the date range (DateTime or Date).
      Uses half-open interval `[from, to)`: from is inclusive, to is exclusive.
    * OR `:date_range` - A `Date.Range` struct (e.g., `Date.range(~D[2024-01-01], ~D[2024-01-31])`).
      Both ends are inclusive `[first, last]`.

  ## Optional Options

    * `:price_type` - `:bid` (default), `:ask`, or `:mid`
    * `:utc_offset` - Fixed UTC offset as Time (default: `~T[00:00:00]`)
    * `:timezone` - Timezone string with DST support (default: `"Etc/UTC"`)
    * `:volume_units` - `:millions` (default), `:thousands`, or `:units`
    * `:ignore_flats` - Ignore zero-volume bars (default: `true`). Does not apply to ticks.
    * `:batch_size` - Number of parallel requests per batch (default: `10`)
    * `:pause_between_batches_ms` - Pause between batches in ms (default: `1000`)
    * `:use_cache` - Enable file caching (default: `false`)
    * `:cache_folder_path` - Cache folder path (default: `".dukascopy-cache"`)
    * `:max_retries` - Number of retries per request (default: `3`)
    * `:retry_on_empty` - Retry on empty response (default: `false`)
    * `:fail_after_retry_count` - Raise error after all retries exhausted (default: `true`)
    * `:retry_delay` - Delay between retries. Can be an integer (fixed ms)
      or a function `(attempt :: integer) -> ms`. Default: exponential backoff `200 * 2^attempt`
    * `:market_open` - Market open time for daily/weekly/monthly alignment (default: `~T[00:00:00]`)
    * `:weekly_open` - Day the week starts (default: `:monday`)

  ## Returns

  A `Stream` that yields `TheoryCraft.MarketSource.Tick` or `TheoryCraft.MarketSource.Bar` structs.

  ## Examples

      # Raw ticks for a single day
      iex> Dukascopy.stream("EUR/USD", :ticks, from: ~D[2024-11-15], to: ~D[2024-11-16])
      ...> |> Enum.take(1000)

      # 5-minute bars with mid price
      iex> Dukascopy.stream("EUR/USD", "m5",
      ...>   from: ~D[2024-01-01],
      ...>   to: ~D[2024-01-31],
      ...>   price_type: :mid
      ...> )
      ...> |> Enum.to_list()

      # Daily bars with caching enabled
      iex> Dukascopy.stream("EUR/USD", "D",
      ...>   date_range: Date.range(~D[2020-01-01], ~D[2024-01-01]),
      ...>   use_cache: true
      ...> )
      ...> |> Enum.to_list()

      # Weekly bars with custom market open time
      iex> Dukascopy.stream("EUR/USD", "W",
      ...>   from: ~D[2024-01-01],
      ...>   to: ~D[2024-12-31],
      ...>   market_open: ~T[17:00:00],
      ...>   weekly_open: :sunday
      ...> )
      ...> |> Enum.to_list()

  """
  @spec stream(String.t(), timeframe(), Keyword.t()) :: Enumerable.t()
  def stream(instrument, timeframe, opts \\ []) do
    validated_opts = Options.validate!(instrument, timeframe, opts)
    {from, to} = Keyword.fetch!(validated_opts, :date_range)

    {source, strategy} = determine_source_and_strategy(timeframe, from, to)

    feed_opts = Keyword.merge(validated_opts, instrument: instrument, granularity: source)

    # Build MarketSource pipeline
    {market, output_name} =
      %MarketSource{}
      |> MarketSource.add_data({DataFeed, feed_opts}, name: "data")
      |> maybe_resample(strategy, timeframe, validated_opts)

    # Extract Tick/Bar from MarketEvent
    market
    |> MarketSource.stream()
    |> Stream.map(fn %MarketEvent{data: %{^output_name => value}} -> value end)
  end

  ## Private functions - Resample

  defp maybe_resample(market, strategy, timeframe, opts) do
    case strategy do
      :no_resample ->
        {market, "data"}

      :resample ->
        resample_opts = Keyword.merge(opts, bar_only: true, data: "data", name: "resampled")
        {MarketSource.resample(market, timeframe, resample_opts), "resampled"}
    end
  end

  ## Private functions - Source and strategy determination

  defp determine_source_and_strategy(timeframe, from, to) do
    case timeframe do
      :ticks ->
        {:ticks, :no_resample}

      _ ->
        {:ok, {unit, mult}} = TimeFrame.parse(timeframe)
        strategy_for_unit(unit, mult, from, to)
    end
  end

  defp strategy_for_unit(unit, mult, from, to) do
    case {unit, mult} do
      {u, _} when u in ["t", "s"] ->
        {:ticks, :resample}

      {"m", m} ->
        bar_strategy(:minute, m, from, to)

      {"h", m} ->
        bar_strategy(:hour, m, from, to)

      {"D", m} ->
        bar_strategy(:day, m, from, to)

      {u, _} when u in ["W", "M"] ->
        {:day, :resample}
    end
  end

  # For :hour and :day sources with mult=1, check if current period fallback will occur.
  # If fallback occurs, DataFeed returns lower granularity data that needs resampling.
  defp bar_strategy(source, mult, from, to) do
    case {source, mult} do
      {s, 1} when s in [:hour, :day] ->
        if needs_current_period_fallback?(source, from, to),
          do: {source, :resample},
          else: {source, :no_resample}

      {_source, 1} ->
        {source, :no_resample}

      _ ->
        {source, :resample}
    end
  end

  # Check if the date range overlaps with a current period that requires fallback
  defp needs_current_period_fallback?(:hour, _from, to) do
    # For hourly data, fallback occurs if `to` is in the current month
    now = DateTime.utc_now()
    to.year == now.year and to.month == now.month
  end

  defp needs_current_period_fallback?(:day, _from, to) do
    # For daily data, fallback occurs if `to` is in the current year
    now = DateTime.utc_now()
    to.year == now.year
  end
end
