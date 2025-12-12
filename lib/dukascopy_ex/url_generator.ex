defmodule DukascopyEx.UrlGenerator do
  @moduledoc """
  Generates Dukascopy API URLs for downloading market data.

  This module provides functions to generate URLs for different data types:

    - Tick data (hourly files)
    - Minute bars (daily files)
    - Hourly bars (monthly files)
    - Daily bars (yearly files)

  """

  alias DukascopyEx.{Client, Enums, Instruments}

  ## Public API

  @doc """
  Returns the base URL for the Dukascopy datafeed.
  """
  @spec base_url() :: String.t()
  def base_url, do: Client.base_url()

  @doc """
  Generates a list of URLs for the given instrument, timeframe, and date range.

  Uses half-open interval `[from, to)`: from is inclusive, to is exclusive.
  A period is included if its start date is strictly less than `to`.

  ## Parameters

    * `instrument` - Trading instrument (e.g., "EUR/USD")
    * `timeframe` - Data timeframe: `:ticks`, `:minute`, `:hour`, or `:day`
    * `from` - Start datetime (DateTime), inclusive
    * `to` - End datetime (DateTime), exclusive
    * `opts` - Options:
      * `:price_type` - `:bid` (default) or `:ask` (ignored for ticks)
      * `:utc_offset` - Time struct to add to from/to (default: `~T[00:00:00]`)

  ## Returns

    * `{:ok, [String.t()]}` - List of URLs
    * `{:error, {:unknown_instrument, String.t()}}` - Unknown instrument

  ## Examples

      iex> {:ok, urls} = UrlGenerator.generate_urls("EUR/USD", :ticks, ~U[2019-06-22 16:00:00Z], ~U[2019-06-22 18:00:00Z])
      iex> length(urls)
      2

  """
  @spec generate_urls(
          String.t(),
          Enums.granularity_keys(),
          DateTime.t(),
          DateTime.t(),
          Keyword.t()
        ) :: {:ok, [String.t()]} | {:error, {:unknown_instrument, String.t()}}
  def generate_urls(instrument, timeframe, from, to, opts \\ []) do
    case Instruments.get_historical_filename(instrument) do
      nil ->
        {:error, {:unknown_instrument, instrument}}

      filename ->
        price_type = Keyword.get(opts, :price_type, :bid)
        utc_offset = Keyword.get(opts, :utc_offset, ~T[00:00:00])

        utc_from = to_utc(from)
        utc_to = to_utc(to)

        {adjusted_from, adjusted_to} = apply_utc_offset(utc_from, utc_to, utc_offset)
        limited_to = limit_to_now(adjusted_to)

        urls = do_generate_urls(filename, timeframe, adjusted_from, limited_to, price_type)
        {:ok, urls}
    end
  end

  @doc """
  Builds a single URL for tick data.
  """
  @spec build_tick_url(String.t(), Date.t(), 0..23) ::
          {:ok, String.t()} | {:error, {:unknown_instrument, String.t()}}
  def build_tick_url(instrument, date, hour) when hour >= 0 and hour <= 23 do
    case Instruments.get_historical_filename(instrument) do
      nil ->
        {:error, {:unknown_instrument, instrument}}

      filename ->
        url = tick_url(filename, date, hour)
        {:ok, url}
    end
  end

  @doc """
  Builds a single URL for bar data.
  """
  @spec build_bar_url(String.t(), :minute | :hour | :day, Date.t(), Keyword.t()) ::
          {:ok, String.t()} | {:error, {:unknown_instrument, String.t()}}
  def build_bar_url(instrument, timeframe, date, opts \\ [])
      when timeframe in [:minute, :hour, :day] do
    case Instruments.get_historical_filename(instrument) do
      nil ->
        {:error, {:unknown_instrument, instrument}}

      filename ->
        price_type = Keyword.get(opts, :price_type, :bid)
        url = bar_url(filename, timeframe, date, price_type)
        {:ok, url}
    end
  end

  ## Private functions

  defp do_generate_urls(filename, :ticks, from, to, _price_type) do
    from
    |> generate_tick_periods(to)
    |> Enum.map(fn {date, hour} -> tick_url(filename, date, hour) end)
  end

  defp do_generate_urls(filename, timeframe, from, to, price_type) do
    from
    |> generate_bar_periods(timeframe, to)
    |> Enum.map(fn date -> bar_url(filename, timeframe, date, price_type) end)
  end

  ## Private functions - URL building

  defp tick_url(filename, date, hour) do
    %Date{day: day, month: month, year: year} = date

    "#{Client.base_url()}/#{filename}/#{year}/" <>
      "#{format_month(month)}/#{format_day(day)}/" <>
      "#{format_hour(hour)}h_ticks.bi5"
  end

  defp bar_url(filename, :minute, date, price_type) do
    %Date{day: day, month: month, year: year} = date
    price_str = price_type |> Atom.to_string() |> String.upcase()

    "#{Client.base_url()}/#{filename}/#{year}/" <>
      "#{format_month(month)}/#{format_day(day)}/" <>
      "#{price_str}_candles_min_1.bi5"
  end

  defp bar_url(filename, :hour, date, price_type) do
    %Date{month: month, year: year} = date
    price_str = price_type |> Atom.to_string() |> String.upcase()

    "#{Client.base_url()}/#{filename}/#{year}/" <>
      "#{format_month(month)}/#{price_str}_candles_hour_1.bi5"
  end

  defp bar_url(filename, :day, date, price_type) do
    %Date{year: year} = date
    price_str = price_type |> Atom.to_string() |> String.upcase()

    "#{Client.base_url()}/#{filename}/#{year}/#{price_str}_candles_day_1.bi5"
  end

  ## Private functions - Period generation

  defp generate_tick_periods(from, to) do
    from
    |> truncate_to_hour()
    |> Stream.unfold(fn current ->
      if DateTime.compare(current, to) == :lt do
        {{DateTime.to_date(current), current.hour}, DateTime.add(current, 1, :hour)}
      end
    end)
  end

  defp generate_bar_periods(from, :minute, to) do
    from_date = DateTime.to_date(from)

    from_date
    |> Stream.unfold(fn current ->
      current_dt = DateTime.new!(current, ~T[00:00:00], "Etc/UTC")

      if DateTime.compare(current_dt, to) == :lt do
        {current, Date.add(current, 1)}
      end
    end)
  end

  defp generate_bar_periods(from, :hour, to) do
    {from.year, from.month}
    |> Stream.unfold(fn {year, month} ->
      current_dt = DateTime.new!(Date.new!(year, month, 1), ~T[00:00:00], "Etc/UTC")

      if DateTime.compare(current_dt, to) == :lt do
        date = Date.new!(year, month, 1)
        {date, next_month(year, month)}
      end
    end)
  end

  defp generate_bar_periods(from, :day, to) do
    from.year
    |> Stream.unfold(fn year ->
      current_dt = DateTime.new!(Date.new!(year, 1, 1), ~T[00:00:00], "Etc/UTC")

      if DateTime.compare(current_dt, to) == :lt do
        date = Date.new!(year, 1, 1)
        {date, year + 1}
      end
    end)
  end

  ## Private functions - Helpers

  defp to_utc(%DateTime{time_zone: "Etc/UTC"} = dt), do: dt
  defp to_utc(%DateTime{} = dt), do: DateTime.shift_zone!(dt, "Etc/UTC")

  defp apply_utc_offset(from, to, utc_offset) do
    offset_seconds = Time.diff(utc_offset, ~T[00:00:00])

    adjusted_from = DateTime.add(from, offset_seconds, :second)
    adjusted_to = DateTime.add(to, offset_seconds, :second)

    {adjusted_from, adjusted_to}
  end

  defp limit_to_now(to) do
    now = DateTime.utc_now()

    if DateTime.compare(to, now) == :gt do
      now
    else
      to
    end
  end

  defp truncate_to_hour(%DateTime{} = dt) do
    %DateTime{dt | minute: 0, second: 0, microsecond: {0, 0}}
  end

  defp format_month(month), do: String.pad_leading("#{month - 1}", 2, "0")
  defp format_day(day), do: String.pad_leading("#{day}", 2, "0")
  defp format_hour(hour), do: String.pad_leading("#{hour}", 2, "0")

  defp next_month(year, 12), do: {year + 1, 1}
  defp next_month(year, month), do: {year, month + 1}
end
