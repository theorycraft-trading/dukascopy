defmodule Dukascopy.OptionsTest do
  use ExUnit.Case, async: true

  alias Dukascopy.Options

  ## Tests

  describe "validate/3" do
    test "validates with from/to dates" do
      assert {:ok, opts} =
               Options.validate(
                 "EUR/USD",
                 :ticks,
                 from: ~D[2024-01-01],
                 to: ~D[2024-01-02]
               )

      assert {from, to} = opts[:date_range]
      assert from == ~U[2024-01-01 00:00:00Z]
      assert to == ~U[2024-01-02 00:00:00Z]
    end

    test "validates with from/to datetimes" do
      from = ~U[2024-01-01 10:00:00Z]
      to = ~U[2024-01-01 15:00:00Z]

      assert {:ok, opts} = Options.validate("EUR/USD", :ticks, from: from, to: to)
      assert {^from, ^to} = opts[:date_range]
    end

    test "validates with date_range" do
      range = Date.range(~D[2024-01-01], ~D[2024-01-31])

      assert {:ok, opts} = Options.validate("EUR/USD", :ticks, date_range: range)
      assert {from, to} = opts[:date_range]
      assert from == ~U[2024-01-01 00:00:00Z]
      # date_range includes the last day, so we add 1 day
      assert to == ~U[2024-02-01 00:00:00Z]
    end

    test "returns error for unknown instrument" do
      assert {:error, {:unknown_instrument, "UNKNOWN"}} =
               Options.validate("UNKNOWN", :ticks, from: ~D[2024-01-01], to: ~D[2024-01-02])
    end

    test "validates string timeframes" do
      for tf <- ["m1", "m5", "h1", "h4", "D", "W", "M", "t5", "s30"] do
        assert {:ok, _} =
                 Options.validate(
                   "EUR/USD",
                   tf,
                   from: ~D[2024-01-01],
                   to: ~D[2024-01-02]
                 ),
               "Failed for timeframe: #{tf}"
      end
    end

    test "returns error for invalid timeframe" do
      assert {:error, {:invalid_timeframe, "invalid"}} =
               Options.validate("EUR/USD", "invalid", from: ~D[2024-01-01], to: ~D[2024-01-02])

      assert {:error, {:invalid_timeframe, 123}} =
               Options.validate("EUR/USD", 123, from: ~D[2024-01-01], to: ~D[2024-01-02])
    end

    test "applies default options" do
      assert {:ok, opts} =
               Options.validate(
                 "EUR/USD",
                 :ticks,
                 from: ~D[2024-01-01],
                 to: ~D[2024-01-02]
               )

      assert opts[:price_type] == :bid
      assert opts[:utc_offset] == ~T[00:00:00]
      assert opts[:timezone] == "Etc/UTC"
      assert opts[:volume_units] == :millions
      assert opts[:ignore_flats] == true
      assert opts[:batch_size] == 10
      assert opts[:pause_between_batches_ms] == 1000
      assert opts[:use_cache] == false
      assert opts[:cache_folder_path] == ".dukascopy-cache"
      assert opts[:max_retries] == 3
      assert opts[:retry_on_empty] == false
      assert opts[:fail_after_retry_count] == true
      assert is_function(opts[:retry_delay], 1)
      assert opts[:market_open] == ~T[00:00:00]
      assert opts[:weekly_open] == :monday
    end

    test "allows overriding options" do
      assert {:ok, opts} =
               Options.validate("EUR/USD", :ticks,
                 from: ~D[2024-01-01],
                 to: ~D[2024-01-02],
                 price_type: :mid,
                 batch_size: 5,
                 volume_units: :units
               )

      assert opts[:price_type] == :mid
      assert opts[:batch_size] == 5
      assert opts[:volume_units] == :units
    end

    test "validates price_type option" do
      for pt <- [:bid, :ask, :mid] do
        assert {:ok, _} =
                 Options.validate("EUR/USD", :ticks,
                   from: ~D[2024-01-01],
                   to: ~D[2024-01-02],
                   price_type: pt
                 )
      end

      assert {:error, {:invalid_price_type, :invalid}} =
               Options.validate("EUR/USD", :ticks,
                 from: ~D[2024-01-01],
                 to: ~D[2024-01-02],
                 price_type: :invalid
               )
    end

    test "validates volume_units option" do
      for vu <- [:millions, :thousands, :units] do
        assert {:ok, _} =
                 Options.validate("EUR/USD", :ticks,
                   from: ~D[2024-01-01],
                   to: ~D[2024-01-02],
                   volume_units: vu
                 )
      end

      assert {:error, {:invalid_volume_units, :invalid}} =
               Options.validate("EUR/USD", :ticks,
                 from: ~D[2024-01-01],
                 to: ~D[2024-01-02],
                 volume_units: :invalid
               )
    end

    test "validates utc_offset option" do
      assert {:ok, opts} =
               Options.validate("EUR/USD", :ticks,
                 from: ~D[2024-01-01],
                 to: ~D[2024-01-02],
                 utc_offset: ~T[02:30:00]
               )

      assert opts[:utc_offset] == ~T[02:30:00]

      assert {:error, {:invalid_utc_offset, 150}} =
               Options.validate("EUR/USD", :ticks,
                 from: ~D[2024-01-01],
                 to: ~D[2024-01-02],
                 utc_offset: 150
               )
    end

    test "validates weekly_open option" do
      for day <- [:monday, :tuesday, :wednesday, :thursday, :friday, :saturday, :sunday] do
        assert {:ok, _} =
                 Options.validate("EUR/USD", :ticks,
                   from: ~D[2024-01-01],
                   to: ~D[2024-01-02],
                   weekly_open: day
                 )
      end

      assert {:error, {:invalid_weekly_open, :invalid}} =
               Options.validate("EUR/USD", :ticks,
                 from: ~D[2024-01-01],
                 to: ~D[2024-01-02],
                 weekly_open: :invalid
               )
    end

    test "validates batch_size must be positive" do
      assert {:error, {:invalid_positive_integer, :batch_size, 0}} =
               Options.validate("EUR/USD", :ticks,
                 from: ~D[2024-01-01],
                 to: ~D[2024-01-02],
                 batch_size: 0
               )

      assert {:error, {:invalid_positive_integer, :batch_size, -1}} =
               Options.validate("EUR/USD", :ticks,
                 from: ~D[2024-01-01],
                 to: ~D[2024-01-02],
                 batch_size: -1
               )
    end

    test "validates max_retries must be non-negative" do
      assert {:ok, _} =
               Options.validate("EUR/USD", :ticks,
                 from: ~D[2024-01-01],
                 to: ~D[2024-01-02],
                 max_retries: 0
               )

      assert {:error, {:invalid_non_negative_integer, :max_retries, -1}} =
               Options.validate("EUR/USD", :ticks,
                 from: ~D[2024-01-01],
                 to: ~D[2024-01-02],
                 max_retries: -1
               )
    end
  end

  describe "validate!/3" do
    test "returns validated options on success" do
      opts = Options.validate!("EUR/USD", :ticks, from: ~D[2024-01-01], to: ~D[2024-01-02])
      assert is_list(opts)
      assert opts[:date_range]
    end

    test "raises ArgumentError on failure" do
      assert_raise ArgumentError, ~r/Unknown instrument/, fn ->
        Options.validate!("UNKNOWN", :ticks, from: ~D[2024-01-01], to: ~D[2024-01-02])
      end

      assert_raise ArgumentError, ~r/Missing date range/, fn ->
        Options.validate!("EUR/USD", :ticks, [])
      end

      assert_raise ArgumentError, ~r/Invalid timeframe/, fn ->
        Options.validate!("EUR/USD", "invalid", from: ~D[2024-01-01], to: ~D[2024-01-02])
      end
    end
  end

  describe "defaults/0" do
    test "returns default options" do
      defaults = Options.defaults()
      assert is_list(defaults)
      assert defaults[:price_type] == :bid
      assert defaults[:batch_size] == 10
    end
  end

  ## Additional type validation tests

  describe "type validation" do
    test "rejects non-string instrument" do
      assert {:error, {:unknown_instrument, 12_345}} =
               Options.validate(12_345, :ticks, from: ~D[2024-01-01], to: ~D[2024-01-02])
    end

    test "rejects numeric price_type" do
      assert {:error, {:invalid_price_type, 0}} =
               Options.validate("EUR/USD", :ticks,
                 from: ~D[2024-01-01],
                 to: ~D[2024-01-02],
                 price_type: 0
               )
    end

    test "utc_offset_as_string: rejects string utc_offset" do
      assert {:error, {:invalid_utc_offset, "xxx"}} =
               Options.validate("EUR/USD", :ticks,
                 from: ~D[2024-01-01],
                 to: ~D[2024-01-02],
                 utc_offset: "xxx"
               )
    end

    test "retry_delay_as_string: rejects string retry_delay" do
      assert {:error, {:invalid_retry_delay, "xxx"}} =
               Options.validate("EUR/USD", :ticks,
                 from: ~D[2024-01-01],
                 to: ~D[2024-01-02],
                 retry_delay: "xxx"
               )
    end

    test "retry_delay accepts integer" do
      assert {:ok, opts} =
               Options.validate("EUR/USD", :ticks,
                 from: ~D[2024-01-01],
                 to: ~D[2024-01-02],
                 retry_delay: 500
               )

      assert opts[:retry_delay] == 500
    end

    test "retry_delay accepts function" do
      delay_fn = fn attempt -> attempt * 100 end

      assert {:ok, opts} =
               Options.validate("EUR/USD", :ticks,
                 from: ~D[2024-01-01],
                 to: ~D[2024-01-02],
                 retry_delay: delay_fn
               )

      assert opts[:retry_delay] == delay_fn
    end
  end

  describe "date validation edge cases" do
    test "rejects missing date range" do
      assert {:error, :missing_date_range} = Options.validate("EUR/USD", :ticks, [])
    end

    test "rejects partial date range (only from)" do
      assert {:error, :partial_date_range} =
               Options.validate("EUR/USD", :ticks, from: ~D[2024-01-01])
    end

    test "rejects partial date range (only to)" do
      assert {:error, :partial_date_range} =
               Options.validate("EUR/USD", :ticks, to: ~D[2024-01-02])
    end

    test "rejects conflicting date_range and from/to" do
      assert {:error, :conflicting_date_options} =
               Options.validate("EUR/USD", :ticks,
                 from: ~D[2024-01-01],
                 to: ~D[2024-01-02],
                 date_range: Date.range(~D[2024-02-01], ~D[2024-02-28])
               )
    end
  end

  ## DataFeed options tests

  describe "feed_defaults/0" do
    test "returns default options for DataFeed" do
      defaults = Options.feed_defaults()

      assert defaults[:granularity] == :ticks
      assert defaults[:price_type] == :bid
      assert defaults[:batch_size] == 10
      assert defaults[:pause_between_batches_ms] == 1000
      assert defaults[:max_retries] == 3
      assert is_function(defaults[:retry_delay], 1)
      assert defaults[:use_cache] == false
      assert defaults[:cache_folder_path] == ".dukascopy-cache"
    end

    test "includes all options from defaults/0" do
      base_defaults = Options.defaults()
      feed_defaults = Options.feed_defaults()

      for {key, _value} <- base_defaults do
        assert Keyword.has_key?(feed_defaults, key), "Missing key: #{key}"
      end
    end

    test "includes retry_on_empty and fail_after_retry_count" do
      defaults = Options.feed_defaults()
      assert defaults[:retry_on_empty] == false
      assert defaults[:fail_after_retry_count] == true
    end

    test "includes halt_on_error defaulting to true" do
      defaults = Options.feed_defaults()
      assert defaults[:halt_on_error] == true
    end

    test "includes market_open and weekly_open" do
      defaults = Options.feed_defaults()
      assert defaults[:market_open] == ~T[00:00:00]
      assert defaults[:weekly_open] == :monday
    end
  end

  describe "validate_feed/1" do
    test "validates with instrument and from/to dates" do
      assert {:ok, opts} =
               Options.validate_feed(
                 instrument: "EUR/USD",
                 from: ~D[2024-01-01],
                 to: ~D[2024-01-02]
               )

      assert opts[:instrument] == "EUR/USD"
      assert {from, to} = opts[:date_range]
      assert from == ~U[2024-01-01 00:00:00Z]
      assert to == ~U[2024-01-02 00:00:00Z]
    end

    test "validates with date_range" do
      range = Date.range(~D[2024-01-01], ~D[2024-01-31])

      assert {:ok, opts} = Options.validate_feed(instrument: "EUR/USD", date_range: range)
      assert {from, to} = opts[:date_range]
      assert from == ~U[2024-01-01 00:00:00Z]
      assert to == ~U[2024-02-01 00:00:00Z]
    end

    test "validates with pre-validated date_range tuple" do
      date_range = {~U[2024-01-01 10:00:00Z], ~U[2024-01-01 15:00:00Z]}

      assert {:ok, opts} = Options.validate_feed(instrument: "EUR/USD", date_range: date_range)
      assert opts[:date_range] == date_range
    end

    test "returns error for missing instrument" do
      assert {:error, :missing_instrument} =
               Options.validate_feed(from: ~D[2024-01-01], to: ~D[2024-01-02])
    end

    test "returns error for unknown instrument" do
      assert {:error, {:unknown_instrument, "UNKNOWN"}} =
               Options.validate_feed(
                 instrument: "UNKNOWN",
                 from: ~D[2024-01-01],
                 to: ~D[2024-01-02]
               )
    end

    test "returns error for missing date range" do
      assert {:error, :missing_date_range} = Options.validate_feed(instrument: "EUR/USD")
    end

    test "applies default options" do
      assert {:ok, opts} =
               Options.validate_feed(
                 instrument: "EUR/USD",
                 from: ~D[2024-01-01],
                 to: ~D[2024-01-02]
               )

      assert opts[:granularity] == :ticks
      assert opts[:price_type] == :bid
      assert opts[:batch_size] == 10
      assert opts[:pause_between_batches_ms] == 1000
    end

    test "validates granularity option" do
      for g <- [:ticks, :minute, :hour, :day] do
        assert {:ok, opts} =
                 Options.validate_feed(
                   instrument: "EUR/USD",
                   from: ~D[2024-01-01],
                   to: ~D[2024-01-02],
                   granularity: g
                 )

        assert opts[:granularity] == g
      end

      assert {:error, {:invalid_granularity, :invalid}} =
               Options.validate_feed(
                 instrument: "EUR/USD",
                 from: ~D[2024-01-01],
                 to: ~D[2024-01-02],
                 granularity: :invalid
               )
    end

    test "validates price_type option" do
      for pt <- [:bid, :ask, :mid] do
        assert {:ok, _} =
                 Options.validate_feed(
                   instrument: "EUR/USD",
                   from: ~D[2024-01-01],
                   to: ~D[2024-01-02],
                   price_type: pt
                 )
      end

      assert {:error, {:invalid_price_type, :invalid}} =
               Options.validate_feed(
                 instrument: "EUR/USD",
                 from: ~D[2024-01-01],
                 to: ~D[2024-01-02],
                 price_type: :invalid
               )
    end

    test "validates batch_size must be positive" do
      assert {:error, {:invalid_positive_integer, :batch_size, 0}} =
               Options.validate_feed(
                 instrument: "EUR/USD",
                 from: ~D[2024-01-01],
                 to: ~D[2024-01-02],
                 batch_size: 0
               )
    end

    test "validates pause_between_batches_ms must be non-negative" do
      assert {:ok, _} =
               Options.validate_feed(
                 instrument: "EUR/USD",
                 from: ~D[2024-01-01],
                 to: ~D[2024-01-02],
                 pause_between_batches_ms: 0
               )

      assert {:error, {:invalid_non_negative_integer, :pause_between_batches_ms, -1}} =
               Options.validate_feed(
                 instrument: "EUR/USD",
                 from: ~D[2024-01-01],
                 to: ~D[2024-01-02],
                 pause_between_batches_ms: -1
               )
    end

    test "validates max_retries must be non-negative" do
      assert {:ok, _} =
               Options.validate_feed(
                 instrument: "EUR/USD",
                 from: ~D[2024-01-01],
                 to: ~D[2024-01-02],
                 max_retries: 0
               )

      assert {:error, {:invalid_non_negative_integer, :max_retries, -1}} =
               Options.validate_feed(
                 instrument: "EUR/USD",
                 from: ~D[2024-01-01],
                 to: ~D[2024-01-02],
                 max_retries: -1
               )
    end

    test "validates retry_delay as integer" do
      assert {:ok, opts} =
               Options.validate_feed(
                 instrument: "EUR/USD",
                 from: ~D[2024-01-01],
                 to: ~D[2024-01-02],
                 retry_delay: 500
               )

      assert opts[:retry_delay] == 500
    end

    test "validates retry_delay as function" do
      delay_fn = fn attempt -> attempt * 100 end

      assert {:ok, opts} =
               Options.validate_feed(
                 instrument: "EUR/USD",
                 from: ~D[2024-01-01],
                 to: ~D[2024-01-02],
                 retry_delay: delay_fn
               )

      assert opts[:retry_delay] == delay_fn
    end

    test "rejects invalid retry_delay" do
      assert {:error, {:invalid_retry_delay, "invalid"}} =
               Options.validate_feed(
                 instrument: "EUR/USD",
                 from: ~D[2024-01-01],
                 to: ~D[2024-01-02],
                 retry_delay: "invalid"
               )
    end

    test "includes all inherited options in validated result" do
      assert {:ok, opts} =
               Options.validate_feed(
                 instrument: "EUR/USD",
                 from: ~D[2024-01-01],
                 to: ~D[2024-01-02]
               )

      # Check inherited options are present
      assert opts[:retry_on_empty] == false
      assert opts[:fail_after_retry_count] == true
      assert opts[:halt_on_error] == true
      assert opts[:ignore_flats] == true
      assert opts[:market_open] == ~T[00:00:00]
      assert opts[:weekly_open] == :monday
    end
  end
end
