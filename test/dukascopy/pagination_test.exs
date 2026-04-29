defmodule Dukascopy.PaginationTest do
  use ExUnit.Case, async: true

  alias Dukascopy.{Cursor, Page}
  alias Dukascopy.TestFixtures

  describe "fetch_page/3" do
    test "paginates raw ticks without missing or duplicating items" do
      opts =
        :page_raw_ticks
        |> TestFixtures.stub_dukascopy()
        |> Keyword.merge(
          from: ~U[2019-02-04 00:00:00Z],
          to: ~U[2019-02-04 00:05:00Z],
          page_size: 123,
          pause_between_batches_ms: 0
        )

      expected = fetch_all_at_once("EUR/USD", :tick, opts)

      assert collect_pages("EUR/USD", :tick, opts) == expected
    end

    test "paginates tick-count bars without missing or duplicating items" do
      opts =
        :page_tick_count_bars
        |> TestFixtures.stub_dukascopy()
        |> Keyword.merge(
          from: ~U[2019-02-04 00:00:00Z],
          to: ~U[2019-02-04 00:05:00Z],
          page_size: 4,
          pause_between_batches_ms: 0
        )

      expected = fetch_all_at_once("EUR/USD", "t37", opts)

      assert collect_pages("EUR/USD", "t37", opts) == expected
    end

    test "paginates arbitrary second bars without missing or duplicating items" do
      opts =
        :page_second_bars
        |> TestFixtures.stub_dukascopy()
        |> Keyword.merge(
          from: ~U[2019-02-04 00:00:00Z],
          to: ~U[2019-02-04 00:05:00Z],
          page_size: 3,
          pause_between_batches_ms: 0
        )

      expected = fetch_all_at_once("EUR/USD", "s30", opts)

      assert collect_pages("EUR/USD", "s30", opts) == expected
    end

    test "paginates resampled m5 bars without missing or duplicating items" do
      opts =
        :page_m5_bars
        |> TestFixtures.stub_dukascopy()
        |> Keyword.merge(
          from: ~D[2019-02-04],
          to: ~D[2019-02-05],
          page_size: 17,
          pause_between_batches_ms: 0
        )

      expected = fetch_all_at_once("EUR/USD", "m5", opts)

      assert collect_pages("EUR/USD", "m5", opts) == expected
    end

    test "resumes from the cursor bucket instead of refetching earlier buckets" do
      first_opts =
        :page_cursor_first
        |> TestFixtures.stub_dukascopy()
        |> Keyword.merge(
          from: ~U[2019-02-04 00:00:00Z],
          to: ~U[2019-02-04 11:00:00Z],
          page_size: 3733,
          batch_size: 1,
          pause_between_batches_ms: 0
        )

      assert {:ok, %Page{items: first_page_items, next_cursor: %Cursor{} = cursor}} =
               Dukascopy.fetch_page("EUR/USD", :tick, first_opts)

      assert length(first_page_items) == 3733
      assert cursor.source_time.hour == 10

      {second_stub_opts, tracker} = TestFixtures.stub_dukascopy_with_tracking(:page_cursor_second)

      second_opts =
        Keyword.merge(second_stub_opts,
          from: ~U[2019-02-04 00:00:00Z],
          to: ~U[2019-02-04 11:00:00Z],
          page_size: 10,
          cursor: cursor,
          batch_size: 1,
          pause_between_batches_ms: 0
        )

      assert {:ok, %Page{items: [_ | _]}} = Dukascopy.fetch_page("EUR/USD", :tick, second_opts)

      assert TestFixtures.get_request_paths(tracker) == [
               "/datafeed/EURUSD/2019/01/04/10h_ticks.bi5"
             ]
    end

    test "uses cache options" do
      cache_path = Path.join(System.tmp_dir!(), "dukascopy_page_cache_#{:rand.uniform(100_000)}")
      on_exit(fn -> File.rm_rf!(cache_path) end)

      {stub_opts, tracker} = TestFixtures.stub_dukascopy_with_tracking(:page_cache)

      opts =
        Keyword.merge(stub_opts,
          from: ~U[2019-02-04 00:00:00Z],
          to: ~U[2019-02-04 00:05:00Z],
          page_size: 10,
          batch_size: 1,
          pause_between_batches_ms: 0,
          use_cache: true,
          cache_folder_path: cache_path
        )

      assert {:ok, %Page{items: [_ | _]}} = Dukascopy.fetch_page("EUR/USD", :tick, opts)

      assert TestFixtures.get_request_paths(tracker) == [
               "/datafeed/EURUSD/2019/01/04/00h_ticks.bi5"
             ]

      assert {:ok, %Page{items: [_ | _]}} = Dukascopy.fetch_page("EUR/USD", :tick, opts)

      assert TestFixtures.get_request_paths(tracker) == [
               "/datafeed/EURUSD/2019/01/04/00h_ticks.bi5"
             ]
    end

    test "applies timezone while keeping cursor in source time" do
      opts =
        :page_timezone
        |> TestFixtures.stub_dukascopy()
        |> Keyword.merge(
          from: ~U[2019-02-04 00:00:00Z],
          to: ~U[2019-02-04 00:01:00Z],
          page_size: 1,
          pause_between_batches_ms: 0,
          timezone: "America/New_York"
        )

      assert {:ok, %Page{items: [tick], next_cursor: %Cursor{} = cursor}} =
               Dukascopy.fetch_page("EUR/USD", :tick, opts)

      expected = DateTime.new!(~D[2019-02-03], ~T[19:00:00.994], "America/New_York")
      assert tick.time == expected
      assert cursor.source_time == ~U[2019-02-04 00:00:01.271Z]
      assert cursor.source_skip == 0
    end

    test "applies utc_offset option" do
      opts =
        :page_utc_offset
        |> TestFixtures.stub_dukascopy()
        |> Keyword.merge(
          from: ~U[2019-02-04 00:00:00Z],
          to: ~U[2019-02-04 00:01:00Z],
          page_size: 1,
          pause_between_batches_ms: 0,
          utc_offset: ~T[02:00:00]
        )

      assert {:ok, %Page{items: [tick]}} = Dukascopy.fetch_page("EUR/USD", :tick, opts)

      assert tick.time == ~U[2019-02-04 02:00:00.994Z]
    end

    test "applies volume_units option" do
      base_opts =
        :page_volume_units
        |> TestFixtures.stub_dukascopy()
        |> Keyword.merge(
          from: ~U[2019-02-04 00:00:00Z],
          to: ~U[2019-02-04 00:01:00Z],
          page_size: 1,
          pause_between_batches_ms: 0
        )

      assert {:ok, %Page{items: [tick_millions]}} =
               Dukascopy.fetch_page("EUR/USD", :tick, base_opts)

      assert {:ok, %Page{items: [tick_units]}} =
               Dukascopy.fetch_page(
                 "EUR/USD",
                 :tick,
                 Keyword.put(base_opts, :volume_units, :units)
               )

      assert tick_units.bid_volume == tick_millions.bid_volume * 1_000_000
      assert tick_units.ask_volume == tick_millions.ask_volume * 1_000_000
    end

    test "applies price_type option to bar pages" do
      opts =
        :page_price_type_mid
        |> TestFixtures.stub_dukascopy()
        |> Keyword.merge(
          from: ~D[2019-02-04],
          to: ~D[2019-02-05],
          page_size: 1,
          price_type: :mid,
          batch_size: 2,
          pause_between_batches_ms: 0
        )

      assert {:ok, %Page{items: [bar]}} = Dukascopy.fetch_page("EUR/USD", "m1", opts)

      assert bar.time == ~U[2019-02-04 00:00:00Z]
      assert_in_delta bar.open, 1.14544, 0.000001
      assert_in_delta bar.high, 1.14572, 0.000001
      assert_in_delta bar.low, 1.145435, 0.000001
      assert_in_delta bar.close, 1.145715, 0.000001
      assert_in_delta bar.volume, 695.63, 0.01
    end

    test "applies ignore_flats option to bar pages" do
      base_opts =
        :page_ignore_flats
        |> TestFixtures.stub_dukascopy()
        |> Keyword.merge(
          from: ~D[2020-05-01],
          to: ~D[2020-05-02],
          page_size: 2_000,
          pause_between_batches_ms: 0
        )

      assert {:ok, %Page{items: filtered_bars}} =
               Dukascopy.fetch_page("EUR/USD", "m1", base_opts)

      assert {:ok, %Page{items: all_bars}} =
               Dukascopy.fetch_page(
                 "EUR/USD",
                 "m1",
                 Keyword.put(base_opts, :ignore_flats, false)
               )

      assert Enum.all?(filtered_bars, &(&1.volume > 0))
      assert Enum.any?(all_bars, &(&1.volume == 0.0))
      assert length(all_bars) > length(filtered_bars)
    end

    test "rejects invalid page sizes" do
      base_opts = [
        from: ~U[2019-02-04 00:00:00Z],
        to: ~U[2019-02-04 00:05:00Z]
      ]

      assert {:error, {:invalid_page_size, 0}} =
               Dukascopy.fetch_page("EUR/USD", :tick, Keyword.put(base_opts, :page_size, 0))

      assert {:error, {:invalid_page_size, -1}} =
               Dukascopy.fetch_page("EUR/USD", :tick, Keyword.put(base_opts, :page_size, -1))
    end
  end

  defp collect_pages(instrument, timeframe, opts) do
    collect_pages(instrument, timeframe, opts, nil, [])
  end

  defp collect_pages(instrument, timeframe, opts, cursor, acc) do
    opts =
      case cursor do
        nil -> opts
        %Cursor{} -> Keyword.put(opts, :cursor, cursor)
      end

    assert {:ok, %Page{} = page} = Dukascopy.fetch_page(instrument, timeframe, opts)

    acc = acc ++ page.items

    case page.next_cursor do
      nil -> acc
      %Cursor{} = next_cursor -> collect_pages(instrument, timeframe, opts, next_cursor, acc)
    end
  end

  defp fetch_all_at_once(instrument, timeframe, opts) do
    opts =
      opts
      |> Keyword.drop([:cursor])
      |> Keyword.put(:page_size, 10_000)

    assert {:ok, %Page{items: items, next_cursor: nil}} =
             Dukascopy.fetch_page(instrument, timeframe, opts)

    items
  end
end
