defmodule Dukascopy.Page do
  @moduledoc false

  #
  # Page returned by paginated Dukascopy reads.
  #
  # `items` contains the requested ticks or bars. `next_cursor` is nil when the
  # source stream is exhausted; otherwise it points to the first item not
  # included in the current page.
  #

  alias __MODULE__
  alias Dukascopy.Cursor

  @enforce_keys [:items, :next_cursor]
  defstruct [:items, :next_cursor]

  @type t(item) :: %Page{
          items: [item],
          next_cursor: Cursor.t() | nil
        }
end
