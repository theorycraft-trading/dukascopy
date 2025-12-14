defmodule DukascopyEx.DataFeed do
  @moduledoc """
  DataFeed implementation for Dukascopy historical market data.

  Implements `TheoryCraft.MarketSource.DataFeed` behaviour to provide
  lazy streams of ticks or bars from Dukascopy's API.

  ## Usage

      # Stream raw ticks
      iex> {:ok, stream} = DukascopyEx.DataFeed.stream(
      ...>   instrument: "EUR/USD",
      ...>   from: ~U[2024-01-01 00:00:00Z],
      ...>   to: ~U[2024-01-02 00:00:00Z]
      ...> )

      # Stream minute bars
      iex> {:ok, stream} = DukascopyEx.DataFeed.stream(
      ...>   instrument: "EUR/USD",
      ...>   from: ~D[2024-01-01],
      ...>   to: ~D[2024-01-31],
      ...>   granularity: :minute,
      ...>   price_type: :bid
      ...> )

  ## Required options

    * `:instrument` - Trading instrument (e.g., "EUR/USD")
    * `:from` / `:to` - Date range (DateTime or Date). Half-open interval `[from, to)`
    * `:date_range` - Alternative to `:from/:to`. A `Date.Range` struct (inclusive)

  ## DataFeed-specific options

    * `:granularity` - Data granularity (default: `:ticks`)
      * `:ticks` - Raw tick data
      * `:minute` - 1-minute bars
      * `:hour` - 1-hour bars
      * `:day` - Daily bars
    * `:halt_on_error` - Whether to crash on fetch errors (default: `true`)
      When `true`, raises an error on failed fetches. When `false`, logs the error
      and continues with an empty result.

  ## Inherited options (from `Options.defaults/0`)

    * `:price_type` - `:bid` (default), `:ask`, or `:mid`
      * For ticks: All price types return the same data (ticks contain both bid and ask)
      * For bars: `:mid` calculates `(bid + ask) / 2` and requires **2x HTTP requests**
        (batch_size is automatically halved to maintain the same request rate)
    * `:batch_size` - Parallel requests per batch (default: `10`)
    * `:pause_between_batches_ms` - Pause between batches in ms (default: `1000`)
    * `:max_retries` - Number of retries per request (default: `3`)
    * `:retry_delay` - Delay between retries (default: exponential backoff)
    * `:retry_on_empty` - Retry on empty response (default: `false`)
    * `:fail_after_retry_count` - Return error after all retries (default: `true`)
    * `:use_cache` - Enable file caching (default: `false`)
    * `:cache_folder_path` - Cache folder path (default: `".dukascopy-cache"`)
    * `:ignore_flats` - Ignore zero-volume bars (default: `true`). Does not apply to ticks.
    * `:volume_units` - Volume unit: `:millions` (default), `:thousands`, or `:units`
    * `:timezone` - Timezone string for time adjustment (default: `"Etc/UTC"`)
    * `:utc_offset` - Fixed UTC offset as Time (default: `~T[00:00:00]`)
    * `:market_open` - Market open time for alignment (default: `~T[00:00:00]`)
    * `:weekly_open` - Week start day (default: `:monday`)

  """

  use TheoryCraft.MarketSource.DataFeed

  require Logger

  alias DukascopyEx.{BarData, Options, TickData}
  alias DukascopyEx.Helpers.PeriodGenerator
  alias TheoryCraft.MarketSource.{Bar, Tick}

  ## Public API

  @impl true
  def stream(opts) do
    with {:ok, validated} <- Options.validate_feed(opts) do
      stream =
        case Keyword.fetch!(validated, :granularity) do
          :ticks -> build_tick_stream(validated)
          granularity -> build_bar_stream(granularity, validated)
        end

      {:ok, apply_filters(stream, validated)}
    end
  end

  ## Private functions - Stream building

  defp build_tick_stream(opts) do
    instrument = Keyword.fetch!(opts, :instrument)
    {from, to} = Keyword.fetch!(opts, :date_range)
    batch_size = Keyword.fetch!(opts, :batch_size)
    pause_ms = Keyword.fetch!(opts, :pause_between_batches_ms)

    from
    |> PeriodGenerator.tick_periods(to)
    |> batch_fetch(batch_size, pause_ms, opts, fn {date, hour} ->
      TickData.fetch!(instrument, date, hour, opts)
    end)
    |> Stream.filter(&in_date_range?(&1, from, to))
  end

  defp build_bar_stream(granularity, opts) do
    instrument = Keyword.fetch!(opts, :instrument)
    {from, to} = Keyword.fetch!(opts, :date_range)
    batch_size = Keyword.fetch!(opts, :batch_size)
    pause_ms = Keyword.fetch!(opts, :pause_between_batches_ms)
    price_type = Keyword.fetch!(opts, :price_type)

    # :mid fetches both bid and ask (2x HTTP requests) → halve batch_size
    effective_batch_size =
      case price_type do
        :mid -> max(1, div(batch_size, 2))
        _ -> batch_size
      end

    granularity
    |> PeriodGenerator.bar_periods(from, to)
    |> batch_fetch(effective_batch_size, pause_ms, opts, fn {fetch_granularity, period} ->
      # fetch_granularity may differ from requested granularity due to current period fallback
      BarData.fetch!(instrument, fetch_granularity, period, opts)
    end)
    |> Stream.filter(&in_date_range?(&1, from, to))
  end

  ## Private functions - Batch fetching

  defp batch_fetch(periods, batch_size, pause_ms, opts, fetch_fn) do
    halt_on_error = Keyword.fetch!(opts, :halt_on_error)

    periods
    |> Stream.chunk_every(batch_size)
    |> Stream.intersperse(:pause)
    |> Stream.flat_map(fn
      :pause ->
        Process.sleep(pause_ms)
        []

      batch ->
        DukascopyEx.TaskSupervisor
        |> Task.Supervisor.async_stream_nolink(batch, fetch_fn,
          max_concurrency: batch_size,
          timeout: 60_000,
          ordered: true,
          on_timeout: :kill_task,
          zip_input_on_exit: true
        )
        |> Stream.flat_map(&handle_fetch_result(&1, halt_on_error))
    end)
  end

  defp handle_fetch_result({:ok, items}, _halt_on_error), do: items

  defp handle_fetch_result({:exit, {period, reason}}, halt_on_error) do
    message = "Fetch failed for #{inspect(period)}: #{inspect(reason)}"

    case halt_on_error do
      true ->
        raise message

      false ->
        Logger.error(message)
        []
    end
  end

  ## Private functions - Helpers

  defp in_date_range?(data, from, to) do
    case data do
      %{time: time} -> DateTime.compare(time, from) != :lt and DateTime.compare(time, to) == :lt
      _ -> true
    end
  end

  ## Private functions - Filters

  defp apply_filters(stream, opts) do
    stream
    |> maybe_filter_flats(opts)
    |> maybe_convert_volume(opts)
    |> maybe_apply_time_adjustments(opts)
  end

  # Note: ignore_flats only applies to bars, not ticks
  defp maybe_filter_flats(stream, opts) do
    if Keyword.fetch!(opts, :ignore_flats) do
      Stream.reject(stream, fn
        %Tick{} -> false
        %Bar{volume: v} -> (v || 0) == 0
      end)
    else
      stream
    end
  end

  defp maybe_convert_volume(stream, opts) do
    case Keyword.fetch!(opts, :volume_units) do
      :millions -> stream
      :thousands -> Stream.map(stream, &multiply_volume(&1, 1_000))
      :units -> Stream.map(stream, &multiply_volume(&1, 1_000_000))
    end
  end

  defp multiply_volume(data, factor) do
    case data do
      %Tick{} ->
        %Tick{
          data
          | bid_volume: data.bid_volume && data.bid_volume * factor,
            ask_volume: data.ask_volume && data.ask_volume * factor
        }

      %Bar{} ->
        %Bar{data | volume: data.volume && data.volume * factor}
    end
  end

  defp maybe_apply_time_adjustments(stream, opts) do
    timezone = Keyword.fetch!(opts, :timezone)
    utc_offset = Keyword.fetch!(opts, :utc_offset)

    if timezone == "Etc/UTC" and utc_offset == ~T[00:00:00] do
      stream
    else
      Stream.map(stream, &apply_time_adjustment(&1, timezone, utc_offset))
    end
  end

  defp apply_time_adjustment(%_struct{time: time} = tick_or_bar, timezone, utc_offset) do
    ajusted_time =
      time
      |> maybe_shift_timezone(timezone)
      |> maybe_add_offset(utc_offset)

    %{tick_or_bar | time: ajusted_time}
  end

  defp maybe_shift_timezone(dt, tz) do
    case DateTime.shift_zone(dt, tz) do
      {:ok, shifted} ->
        shifted

      {:error, reason} ->
        Logger.error("Failed to shift timezone to #{tz}: #{inspect(reason)}")
        dt
    end
  end

  defp maybe_add_offset(dt, offset) do
    case offset do
      ~T[00:00:00] ->
        dt

      _ ->
        seconds = Time.diff(offset, ~T[00:00:00])
        DateTime.add(dt, seconds, :second)
    end
  end
end
