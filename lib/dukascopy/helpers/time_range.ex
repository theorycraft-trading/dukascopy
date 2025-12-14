defmodule Dukascopy.Helpers.TimeRange do
  @moduledoc false

  #
  # Time range utilities for determining data fetch granularity.
  #
  # Dukascopy stores historical data in files organized by time periods:
  #
  #   - `:year` → yearly daily file (`BID_candles_day_1.bi5`)
  #   - `:month` → monthly hourly file (`BID_candles_hour_1.bi5`)
  #   - `:day` → daily minute file (`BID_candles_min_1.bi5`)
  #   - `:hour` → hourly tick file (`XXh_ticks.bi5`)
  #
  # For current (incomplete) periods, aggregated files don't exist yet on
  # Dukascopy's servers. This module provides fallback logic to use finer
  # granularity files when coarser ones aren't available.
  #

  @typedoc "Time range granularity for file organization"
  @type range :: :year | :month | :day | :hour

  @typedoc "Data granularity"
  @type granularity :: :day | :hour | :minute

  # Mapping from requested data granularity to available fetch ranges.
  # Listed in order of preference (coarsest to finest).
  @range_infer_map %{
    day: [:year, :month, :day],
    hour: [:month, :day],
    minute: [:day]
  }

  ## Public API

  @doc """
  Checks if a date falls within the current (incomplete) time period.

  The check is hierarchical:

    - `:year` → same year as now
    - `:month` → same year AND month as now
    - `:day` → same year, month AND day as now

  ## Examples

      iex> now = DateTime.utc_now()
      iex> TimeRange.current_range?(:year, now)
      true

      iex> past = ~U[2019-06-15 12:00:00Z]
      iex> TimeRange.current_range?(:year, past)
      false

      iex> past = ~U[2019-06-15 12:00:00Z]
      iex> TimeRange.current_range?(:month, past)
      false

      iex> past = ~U[2019-06-15 12:00:00Z]
      iex> TimeRange.current_range?(:day, past)
      false

  """
  @spec current_range?(range(), DateTime.t() | Date.t()) :: boolean()
  def current_range?(:year, date) do
    now = DateTime.utc_now()
    date.year == now.year
  end

  def current_range?(:month, date) do
    now = DateTime.utc_now()
    date.year == now.year and date.month == now.month
  end

  def current_range?(:day, date) do
    now = DateTime.utc_now()
    date.year == now.year and date.month == now.month and date.day == now.day
  end

  @doc """
  Returns the next finer range in the hierarchy.

  ## Examples

      iex> TimeRange.lower_range(:year)
      :month

      iex> TimeRange.lower_range(:month)
      :day

  """
  @spec lower_range(range()) :: range()
  def lower_range(:year), do: :month
  def lower_range(:month), do: :day

  @doc """
  Finds the closest available range that's not in a current period.

  Returns the coarsest range that has complete data available.
  Falls back to finer ranges if the coarser ones are in current periods.

  ## Examples

      # For past dates, returns the preferred (coarsest) range
      iex> past = ~U[2019-06-15 12:00:00Z]
      iex> TimeRange.closest_available_range(:hour, past)
      :month

      iex> past = ~U[2019-06-15 12:00:00Z]
      iex> TimeRange.closest_available_range(:day, past)
      :year

      iex> past = ~U[2019-06-15 12:00:00Z]
      iex> TimeRange.closest_available_range(:minute, past)
      :day

      # For current dates, falls back to finer granularity
      iex> now = DateTime.utc_now()
      iex> TimeRange.closest_available_range(:hour, now)
      :day

  """
  @spec closest_available_range(granularity(), DateTime.t() | Date.t()) :: range()
  def closest_available_range(granularity, date) do
    ranges = Map.get(@range_infer_map, granularity, [:day])
    Enum.find(ranges, List.last(ranges), fn range -> not current_range?(range, date) end)
  end

  @doc """
  Returns the list of available ranges for a given data granularity.

  ## Examples

      iex> TimeRange.available_ranges(:day)
      [:year, :month, :day]

      iex> TimeRange.available_ranges(:hour)
      [:month, :day]

      iex> TimeRange.available_ranges(:minute)
      [:day]

  """
  @spec available_ranges(granularity()) :: [range()]
  def available_ranges(granularity) do
    Map.get(@range_infer_map, granularity, [:day])
  end
end
