defmodule DukascopyEx.OptionsTest do
  use ExUnit.Case, async: true

  alias DukascopyEx.Options

  ## Tests

  describe "validate/3" do
    test "validates with from/to dates" do
      assert {:ok, opts} =
               Options.validate("EUR/USD", :ticks, from: ~D[2024-01-01], to: ~D[2024-01-02])

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

    test "returns error for missing date range" do
      assert {:error, :missing_date_range} = Options.validate("EUR/USD", :ticks, [])
    end

    test "returns error for unknown instrument" do
      assert {:error, {:unknown_instrument, "UNKNOWN"}} =
               Options.validate("UNKNOWN", :ticks, from: ~D[2024-01-01], to: ~D[2024-01-02])
    end

    test "validates :ticks timeframe" do
      assert {:ok, _} =
               Options.validate("EUR/USD", :ticks, from: ~D[2024-01-01], to: ~D[2024-01-02])
    end

    test "validates string timeframes" do
      for tf <- ["m1", "m5", "h1", "h4", "D", "W", "M", "t5", "s30"] do
        assert {:ok, _} =
                 Options.validate("EUR/USD", tf, from: ~D[2024-01-01], to: ~D[2024-01-02]),
               "Failed for timeframe: #{tf}"
      end
    end

    test "returns error for invalid timeframe" do
      assert {:error, {:invalid_timeframe, "invalid"}} =
               Options.validate("EUR/USD", "invalid", from: ~D[2024-01-01], to: ~D[2024-01-02])
    end

    test "returns error for non-string, non-atom timeframe" do
      assert {:error, {:invalid_timeframe, 123}} =
               Options.validate("EUR/USD", 123, from: ~D[2024-01-01], to: ~D[2024-01-02])
    end

    test "applies default options" do
      assert {:ok, opts} =
               Options.validate("EUR/USD", :ticks, from: ~D[2024-01-01], to: ~D[2024-01-02])

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
end
