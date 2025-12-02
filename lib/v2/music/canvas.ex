defmodule V2.Music.Canvas do
  use GenServer
  alias Phoenix.PubSub
  alias V2.Music.Note

  # Client API

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def add_note(x, y, color, waveform) do
    GenServer.call(__MODULE__, {:add_note, x, y, color, waveform})
  end

  def get_notes do
    GenServer.call(__MODULE__, :get_notes)
  end

  def subscribe do
    PubSub.subscribe(V2.PubSub, "canvas")
  end

  # Server Callbacks

  @impl true
  def init(_) do
    {:ok, []}
  end

  @impl true
  def handle_call({:add_note, x, y, color, waveform}, _from, notes) do
    note = %Note{
      id: System.unique_integer([:positive]),
      x: x,
      y: y,
      color: color,
      waveform: waveform || "sine"
    }
    
    new_notes = [note | notes]
    PubSub.broadcast(V2.PubSub, "canvas", {:new_note, note})
    
    {:reply, note, new_notes}
  end

  @impl true
  def handle_call(:get_notes, _from, notes) do
    {:reply, notes, notes}
  end

  def random_color(exclude \\ []) do
    all_colors = [
      "hsl(0, 70%, 60%)",    # Red
      "hsl(35, 70%, 60%)",   # Orange
      "hsl(100, 70%, 60%)",  # Green
      "hsl(170, 70%, 60%)",  # Teal
      "hsl(220, 70%, 60%)",  # Blue
      "hsl(270, 70%, 60%)",  # Purple
      "hsl(330, 70%, 60%)"   # Pink
    ]

    available = all_colors -- exclude
    
    if available == [] do
      Enum.random(all_colors)
    else
      Enum.random(available)
    end
  end
end

