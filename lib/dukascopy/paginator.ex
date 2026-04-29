defmodule Dukascopy.Paginator do
  @moduledoc false

  #
  # Cursor-based pagination for Dukascopy streams.
  #
  # Pagination is based on positions in the source data feed. This keeps page
  # resumption cheap even for large ranges and works for resampled timeframes,
  # including tick-count bars.
  #

  alias Dukascopy.{Cursor, DataFeed, Page}
  alias TheoryCraft.MarketSource.{MarketEvent, ResampleProcessor}

  @doc false
  @spec fetch_page(
          String.t(),
          Dukascopy.timeframe(),
          atom(),
          :no_resample | :resample,
          Keyword.t(),
          pos_integer(),
          Cursor.t() | nil
        ) :: {:ok, Page.t(term())} | {:error, term()}
  def fetch_page(instrument, timeframe, source, strategy, opts, page_size, cursor) do
    {from, to} = Keyword.fetch!(opts, :date_range)
    effective_from = effective_from(from, cursor)

    feed_opts =
      opts
      |> Keyword.merge(instrument: instrument, granularity: source)
      |> Keyword.put(:date_range, {effective_from, to})
      |> Keyword.put(:cursor, cursor)

    with {:ok, source_stream} <- DataFeed.cursor_stream(feed_opts) do
      stream = maybe_resample(source_stream, strategy, timeframe, opts)
      {:ok, take_page(stream, page_size)}
    end
  end

  defp effective_from(from, nil), do: from
  defp effective_from(_from, %Cursor{source_time: source_time}), do: source_time

  defp maybe_resample(source_stream, :no_resample, _timeframe, _opts), do: source_stream

  defp maybe_resample(source_stream, :resample, timeframe, opts) do
    processor_opts =
      opts
      |> Keyword.take([:price_type, :fake_volume?, :market_open, :weekly_open])
      |> Keyword.merge(data: "data", name: "resampled", timeframe: timeframe)

    {:ok, processor} =
      ResampleProcessor.init(processor_opts)

    Stream.transform(
      source_stream,
      fn ->
        %{
          processor: processor,
          stored_bar: nil,
          stored_cursor: nil,
          stored_new_bar?: nil,
          stored_new_market?: nil
        }
      end,
      &resample_step/2,
      &flush_resampled_stream/1,
      fn _acc -> :ok end
    )
  end

  defp resample_step({source_item, source_cursor}, acc) do
    event = %MarketEvent{
      time: source_item.time,
      source: "data",
      data: %{"data" => source_item}
    }

    {:ok, %MarketEvent{data: %{"resampled" => bar}}, processor} =
      ResampleProcessor.next(event, acc.processor)

    handle_resampled_bar(bar, source_cursor, %{acc | processor: processor})
  end

  defp handle_resampled_bar(%{new_bar?: true} = bar, source_cursor, acc) do
    {emit_stored_bar(acc), store_bar(acc, bar, source_cursor)}
  end

  defp handle_resampled_bar(%{new_bar?: false} = bar, _source_cursor, acc) do
    {[], %{acc | stored_bar: bar}}
  end

  defp flush_resampled_stream(acc), do: {emit_stored_bar(acc), acc}

  defp emit_stored_bar(%{stored_bar: nil}), do: []

  defp emit_stored_bar(acc) do
    bar = %{acc.stored_bar | new_bar?: acc.stored_new_bar?, new_market?: acc.stored_new_market?}
    [{bar, acc.stored_cursor}]
  end

  defp store_bar(acc, bar, cursor) do
    %{
      acc
      | stored_bar: bar,
        stored_cursor: cursor,
        stored_new_bar?: bar.new_bar?,
        stored_new_market?: bar.new_market?
    }
  end

  defp take_page(stream, page_size) do
    entries = Enum.take(stream, page_size + 1)
    {page_entries, overflow_entries} = Enum.split(entries, page_size)

    items = Enum.map(page_entries, fn {item, _cursor} -> item end)

    next_cursor =
      case overflow_entries do
        [{_item, cursor} | _] -> cursor
        [] -> nil
      end

    %Page{items: items, next_cursor: next_cursor}
  end
end
