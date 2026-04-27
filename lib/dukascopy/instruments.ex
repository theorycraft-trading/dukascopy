defmodule Dukascopy.Instruments do
  @moduledoc """
  List of available trading instruments on Dukascopy.

  This module loads instrument data from `priv/instruments.json` at compile time.
  Run `mix dukascopy.gen.instruments` to download the latest instrument data.
  """

  @external_resource "priv/instruments.json"

  # NOTE: Elixir 1.18 use the new JSON module
  @instruments_data @external_resource |> File.read!() |> Jason.decode!()

  @groups Map.fetch!(@instruments_data, "groups")
  @instruments Map.fetch!(@instruments_data, "instruments")

  @type history_granularity :: :tick | :minute | :hour | :day

  @history_start_fields %{
    tick: "history_start_tick",
    minute: "history_start_60sec",
    hour: "history_start_60min",
    # Dukascopy currently reports history_start_day as 0 for all instruments.
    day: "history_start_60min"
  }

  @history_start_field_names @history_start_fields
                             |> Map.values()
                             |> Enum.uniq()

  get_parent = fn info, target, get_parent ->
    cond do
      Map.fetch!(info, "id") == target ->
        true

      Map.get(info, "parent") != nil ->
        parent_info = Map.fetch!(@groups, info["parent"])
        get_parent.(parent_info, target, get_parent)

      true ->
        false
    end
  end

  get_group_instruments = fn group_id ->
    instruments =
      for {_group_id, group_info} <- @groups,
          get_parent.(group_info, group_id, get_parent),
          instrument <- Map.get(group_info, "instruments", []),
          # NOTE: Some instruments may be missing in the instruments map.
          # This happens when instruments are delisted (e.g., stocks merged/acquired like
          # BBT.US/USD, CELG.US/USD, RHT.US/USD) or retired from trading (e.g., EUR/RUB, USD/RUB).
          # The Dukascopy API keeps these instruments in groups for historical reference,
          # but they're no longer available in the active instruments list.
          instrument_info = Map.get(@instruments, instrument),
          not is_nil(instrument_info) do
        Map.fetch!(instrument_info, "name")
      end

    instruments |> Enum.uniq() |> Enum.sort()
  end

  @all_instruments @instruments
                   |> Enum.map(fn {_k, v} -> Map.fetch!(v, "name") end)
                   |> Enum.sort()
  @fx_instruments get_group_instruments.("FX")
  @fx_major_instruments get_group_instruments.("FX_MAJORS")
  @fx_crosses_instruments get_group_instruments.("FX_CROSSES")
  @stocks_instruments get_group_instruments.("STCK_CFD")
  @indices_instruments get_group_instruments.("IDX")
  @metals_instruments get_group_instruments.("FX_METALS")
  @commodities_instruments get_group_instruments.("CMD")
  @agriculturals_instruments get_group_instruments.("CMD_AGRICULTURAL")
  @crypto_instruments get_group_instruments.("VCCY")
  @history_starts_by_instrument Map.new(@instruments, fn {_id, instrument_info} ->
                                  name = Map.fetch!(instrument_info, "name")

                                  {name, Map.take(instrument_info, @history_start_field_names)}
                                end)

  ## Public API

  @doc """
  Search for instruments matching the given query.

  The search is case-insensitive and matches any part of the instrument name.

  ## Examples

      iex> Instruments.search("gas")
      ["GAS.CMD/USD", "GAS.ES/EUR"]
      iex> Instruments.search("AAPL")
      ["AAPL.US/USD"]

  """
  @spec search(String.t()) :: [String.t()]
  def search(query) do
    query = String.upcase(query)

    @all_instruments
    |> Enum.filter(&String.contains?(String.upcase(&1), query))
  end

  @doc """
  Returns the list of all available instruments.

  ## Examples

      iex> instruments = Instruments.all()
      iex> "EUR/USD" in instruments
      true
      iex> "AAPL.US/USD" in instruments
      true

  """
  @spec all() :: [String.t()]
  def all(), do: @all_instruments

  @doc """
  Returns the list of all Forex instruments.

  ## Examples

      iex> forex = Instruments.forex()
      iex> "EUR/USD" in forex
      true
      iex> "GBP/JPY" in forex
      true

  """
  @spec forex() :: [String.t()]
  def forex(), do: @fx_instruments

  @doc """
  Returns the list of all Forex Major instruments.

  ## Examples

      iex> Instruments.forex_majors()
      ["AUD/USD", "EUR/USD", "GBP/USD", "NZD/USD", "USD/CAD", "USD/CHF", "USD/JPY"]

  """
  @spec forex_majors() :: [String.t()]
  def forex_majors(), do: @fx_major_instruments

  @doc """
  Returns the list of all Forex Crosses instruments.

  ## Examples

      iex> crosses = Instruments.forex_crosses()
      iex> "EUR/GBP" in crosses
      true
      iex> "EUR/JPY" in crosses
      true

  """
  @spec forex_crosses() :: [String.t()]
  def forex_crosses(), do: @fx_crosses_instruments

  @doc """
  Returns the list of all Stocks instruments.

  ## Examples

      iex> stocks = Instruments.stocks()
      iex> "AAPL.US/USD" in stocks
      true
      iex> "TSLA.US/USD" in stocks
      true

  """
  @spec stocks() :: [String.t()]
  def stocks(), do: @stocks_instruments

  @doc """
  Returns the list of all Index CFD instruments.

  ## Examples

      iex> indices = Instruments.indices()
      iex> "USA30.IDX/USD" in indices
      true
      iex> "USATECH.IDX/USD" in indices
      true

  """
  @spec indices() :: [String.t()]
  def indices(), do: @indices_instruments

  @doc """
  Returns the list of all Metals instruments.

  ## Examples

      iex> metals = Instruments.metals()
      iex> "XAU/USD" in metals
      true
      iex> "XAG/USD" in metals
      true

  """
  @spec metals() :: [String.t()]
  def metals(), do: @metals_instruments

  @doc """
  Returns the list of all Commodities instruments.

  ## Examples

      iex> commodities = Instruments.commodities()
      iex> "BRENT.CMD/USD" in commodities
      true
      iex> "COPPER.CMD/USD" in commodities
      true

  """
  @spec commodities() :: [String.t()]
  def commodities(), do: @commodities_instruments

  @doc """
  Returns the list of all Agricultural instruments.

  ## Examples

      iex> agriculturals = Instruments.agriculturals()
      iex> "COCOA.CMD/USD" in agriculturals
      true
      iex> "COFFEE.CMD/USX" in agriculturals
      true

  """
  @spec agriculturals() :: [String.t()]
  def agriculturals(), do: @agriculturals_instruments

  @doc """
  Returns the list of all Crypto CFD instruments.

  ## Examples

      iex> crypto = Instruments.crypto()
      iex> "BTC/USD" in crypto
      true
      iex> "ETH/USD" in crypto
      true

  """
  @spec crypto() :: [String.t()]
  def crypto(), do: @crypto_instruments

  ## History start lookup

  @doc """
  Returns the earliest available historical timestamp for an instrument and native granularity.

  Supported granularities map to Dukascopy's native files:

    * `:tick` - raw tick files
    * `:minute` - native 1-minute bars
    * `:hour` - native 1-hour bars
    * `:day` - daily bars derived from the 1-hour history start because Dukascopy currently
      reports `history_start_day` as `0` for every instrument

  ## Examples

      iex> Instruments.get_history_start("EUR/USD", :minute)
      {:ok, ~U[2007-01-01 00:00:00.000Z]}
      iex> Instruments.get_history_start("EUR/USD", :day)
      {:ok, ~U[2003-05-04 19:00:00.000Z]}
      iex> Instruments.get_history_start("UNKNOWN", :minute)
      {:error, {:unknown_instrument, "UNKNOWN"}}

  """
  @spec get_history_start(String.t(), history_granularity()) ::
          {:ok, DateTime.t()}
          | {:error, {:unknown_instrument, term()}}
          | {:error, :history_start_unknown}
  def get_history_start(instrument, granularity) do
    with {:ok, field} <- fetch_history_start_field(granularity),
         {:ok, starts} <- fetch_history_starts(instrument),
         {:ok, unix_ms} <- parse_history_start_timestamp(Map.get(starts, field)) do
      datetime_from_unix_ms(unix_ms)
    end
  end

  @doc """
  Same as `get_history_start/2` but raises if the lookup fails.

  ## Examples

      iex> Instruments.get_history_start!("EUR/USD", :tick)
      ~U[2007-01-01 00:00:05.163Z]

      iex> Instruments.get_history_start!("UNKNOWN", :tick)
      ** (ArgumentError) unknown instrument: UNKNOWN

  """
  @spec get_history_start!(String.t(), history_granularity()) :: DateTime.t()
  def get_history_start!(instrument, granularity) do
    case get_history_start(instrument, granularity) do
      {:ok, datetime} ->
        datetime

      {:error, {:unknown_instrument, unknown_instrument}} ->
        raise ArgumentError, "unknown instrument: #{unknown_instrument}"

      {:error, {:unsupported_granularity, unsupported_granularity}} ->
        raise ArgumentError, "unsupported granularity: #{inspect(unsupported_granularity)}"

      {:error, :history_start_unknown} ->
        raise ArgumentError,
              "history start unknown for #{instrument} at #{inspect(granularity)} granularity"
    end
  end

  ## Historical filename lookup

  @doc """
  Returns the historical filename for a given instrument name.

  The historical filename is used for constructing Dukascopy API URLs.
  It removes dots and slashes from the instrument name.

  ## Examples

      iex> Instruments.get_historical_filename("EUR/USD")
      "EURUSD"
      iex> Instruments.get_historical_filename("AAPL.US/USD")
      "AAPLUSUSD"
      iex> Instruments.get_historical_filename("0005.HK/HKD")
      "0005HKHKD"
      iex> Instruments.get_historical_filename("UNKNOWN")
      nil

  """
  @spec get_historical_filename(String.t()) :: String.t() | nil
  for {_instrument_id, %{"name" => name, "historical_filename" => filename}} <- @instruments do
    def get_historical_filename(unquote(name)) do
      unquote(filename)
    end
  end

  def get_historical_filename(_instrument_name), do: nil

  @doc """
  Same as `get_historical_filename/1` but raises if instrument is not found.

  ## Examples

      iex> Instruments.get_historical_filename!("EUR/USD")
      "EURUSD"

      iex> Instruments.get_historical_filename!("UNKNOWN")
      ** (ArgumentError) unknown instrument: UNKNOWN

  """
  @spec get_historical_filename!(String.t()) :: String.t()
  def get_historical_filename!(instrument_name) do
    get_historical_filename(instrument_name) ||
      raise ArgumentError, "unknown instrument: #{instrument_name}"
  end

  ## Pip value lookup

  @doc """
  Returns the pip value for a given instrument name.

  The pip value is used to convert integer prices from Dukascopy's binary format
  to decimal prices. Formula: point_value = 10 / pip_value.

  ## Examples

      iex> Instruments.get_pip_value("EUR/USD")
      0.0001
      iex> Instruments.get_pip_value("USD/JPY")
      0.01
      iex> Instruments.get_pip_value("XAU/USD")
      0.01
      iex> Instruments.get_pip_value("BTC/USD")
      1
      iex> Instruments.get_pip_value("UNKNOWN")
      nil

  """
  @spec get_pip_value(String.t()) :: float() | integer() | nil
  for {_instrument_id, %{"name" => name, "pipValue" => pip_value}} <- @instruments do
    def get_pip_value(unquote(name)) do
      unquote(pip_value)
    end
  end

  def get_pip_value(_instrument_name), do: nil

  @doc """
  Same as `get_pip_value/1` but raises if instrument is not found.

  ## Examples

      iex> Instruments.get_pip_value!("EUR/USD")
      0.0001
      
      iex> Instruments.get_pip_value!("UNKNOWN")
      ** (ArgumentError) unknown instrument: UNKNOWN

  """
  @spec get_pip_value!(String.t()) :: float() | integer()
  def get_pip_value!(instrument_name) do
    get_pip_value(instrument_name) ||
      raise ArgumentError, "unknown instrument: #{instrument_name}"
  end

  ## Point value lookup

  # Some instruments have special point_value overrides (from dukascopy-node)
  @point_value_overrides %{
    "BAT/USD" => 100_000,
    "UNI/USD" => 1_000,
    "LNK/USD" => 1_000
  }

  @doc """
  Returns the point value for a given instrument.

  The point value is used to convert integer prices from Dukascopy's binary format
  to decimal prices.

  ## Options

    * `:point_value` - Override the point value (bypasses all lookups)

  ## Examples

      iex> Instruments.get_point_value("EUR/USD")
      {:ok, 100000.0}
      iex> Instruments.get_point_value("USD/JPY")
      {:ok, 1000.0}
      iex> Instruments.get_point_value("EUR/USD", point_value: 50000)
      {:ok, 50000}
      iex> Instruments.get_point_value("UNKNOWN")
      {:error, {:unknown_instrument, "UNKNOWN"}}

  """
  @spec get_point_value(String.t(), Keyword.t()) :: {:ok, number()} | {:error, term()}
  def get_point_value(instrument, opts \\ []) do
    with :error <- Keyword.fetch(opts, :point_value),
         :error <- Map.fetch(@point_value_overrides, instrument) do
      case get_pip_value(instrument) do
        nil -> {:error, {:unknown_instrument, instrument}}
        pip_value -> {:ok, 10 / pip_value}
      end
    end
  end

  defp fetch_history_start_field(granularity) do
    case Map.fetch(@history_start_fields, granularity) do
      {:ok, field} -> {:ok, field}
      :error -> {:error, {:unsupported_granularity, granularity}}
    end
  end

  defp fetch_history_starts(instrument) do
    case Map.fetch(@history_starts_by_instrument, instrument) do
      {:ok, starts} -> {:ok, starts}
      :error -> {:error, {:unknown_instrument, instrument}}
    end
  end

  defp parse_history_start_timestamp(value) when is_binary(value) do
    case Integer.parse(value) do
      {timestamp, ""} when timestamp > 0 -> {:ok, normalize_unix_timestamp(timestamp)}
      _ -> {:error, :history_start_unknown}
    end
  end

  defp parse_history_start_timestamp(_value), do: {:error, :history_start_unknown}

  # Most metadata timestamps are Unix milliseconds, but a few history_start_60sec
  # values are Unix seconds. Anything below this threshold would be before 1973
  # if interpreted as milliseconds, which is invalid for Dukascopy history.
  defp normalize_unix_timestamp(timestamp) when timestamp < 100_000_000_000, do: timestamp * 1000
  defp normalize_unix_timestamp(timestamp), do: timestamp

  defp datetime_from_unix_ms(unix_ms) do
    case DateTime.from_unix(unix_ms, :millisecond) do
      {:ok, datetime} -> {:ok, datetime}
      {:error, _reason} -> {:error, :history_start_unknown}
    end
  end
end
