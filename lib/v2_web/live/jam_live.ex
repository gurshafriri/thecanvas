defmodule V2Web.JamLive do
  use V2Web, :live_view
  alias V2.Music.Canvas
  alias V2Web.Presence

  def mount(_params, _session, socket) do
    user_id = Base.encode16(:crypto.strong_rand_bytes(8))

    # Get currently used colors if connected
    used_colors = 
      if connected?(socket) do
        Presence.list("jam:presence")
        |> Enum.map(fn {_id, meta} -> List.first(meta.metas)[:color] end)
        |> Enum.reject(&is_nil/1)
      else
        []
      end

    user_color = Canvas.random_color(used_colors)
    
    if connected?(socket) do
      Canvas.subscribe()
      V2Web.Endpoint.subscribe("jam:presence")
      {:ok, _} = Presence.track(self(), "jam:presence", user_id, %{
        color: user_color,
        online_at: System.system_time(:second)
      })
    end
    
    notes = Canvas.get_notes()
    base_time = System.os_time(:millisecond) - 100_000 
    
    presences = if connected?(socket), do: Presence.list("jam:presence"), else: %{}
    
    {:ok, 
     socket
     |> assign(:notes, notes)
     |> assign(:base_time, base_time)
     |> assign(:user_color, user_color)
     |> assign(:user_id, user_id)
     |> assign(:users, presences)
     |> assign(:zoom_x, 0.1) # px per ms
     |> assign(:zoom_y, 1.0) # scale factor
     |> assign(:volume, 0.0) # dB
     |> assign(:waveform, "sine")
     |> assign(:page_title, "Musical Canvas")}
  end

  def render(assigns) do
    # Fixed 1-second grid interval
    grid_interval = 1000
    grid_spacing = grid_interval * assigns.zoom_x

    assigns = assign(assigns, :grid_interval, grid_interval)
    assigns = assign(assigns, :grid_spacing, grid_spacing)

    ~H"""
    <div class="flex flex-col h-[100dvh] w-screen bg-[#2c2c2c] overflow-hidden font-sans relative selection:bg-red-500/30 touch-none">
      
      <!-- Top Surface Strip -->
      <div class="h-16 md:h-20 w-full flex-none bg-[#2c2c2c] flex items-center px-4 md:px-8 justify-between z-20 relative border-b border-[#363636]">
          <!-- Branding / Info -->
          <div class="flex flex-col gap-1 opacity-50 hover:opacity-100 transition-opacity">
            <h1 class="text-lg font-bold text-[#e3ded1] tracking-[0.2em] uppercase">The Canvas <span class="text-xs tracking-normal normal-case opacity-50">(WIP)</span></h1>
            <div class="flex items-center gap-4 text-[10px] text-gray-500 font-mono">
              <div class="flex items-center gap-2">
                <div class="w-1.5 h-1.5 rounded-full" style={"background-color: #{@user_color}"}></div>
                <span>Your Color</span>
              </div>
              
              <div class="w-px h-3 bg-gray-700"></div>

              <div class="flex items-center gap-4">
                 <div class="flex -space-x-3">
                    <%= for {id, meta} <- @users, id != @user_id do %>
                       <div class="w-1.5 h-1.5 rounded-full ring-1 ring-[#2c2c2c]" 
                            style={"background-color: #{List.first(meta.metas)[:color]}"}></div>
                    <% end %>
                 </div>
                 <span>{max(0, map_size(@users) - 1)} more players online</span>
              </div>
            </div>
          </div>

          <!-- Created by Gur -->
          <div class="flex md:flex-col items-center gap-4 md:gap-2">
            <div class="flex items-center gap-2">
              <a href="https://github.com/gurshafriri/canvas" target="_blank" class="text-gray-500 hover:text-[#e3ded1] transition-colors" title="View Source on GitHub">
                <svg viewBox="0 0 98 96" class="w-7 h-7 fill-current" xmlns="http://www.w3.org/2000/svg"><path fill-rule="evenodd" clip-rule="evenodd" d="M48.854 0C21.839 0 0 22 0 49.217c0 21.756 13.993 40.172 33.405 46.69 2.427.49 3.316-1.059 3.316-2.362 0-1.141-.08-5.052-.08-9.127-13.59 2.934-16.42-5.867-16.42-5.867-2.184-5.704-5.42-7.17-5.42-7.17-4.448-3.015.324-3.015.324-3.015 4.934.326 7.523 5.052 7.523 5.052 4.367 7.496 11.404 5.378 14.235 4.074.404-3.178 1.699-5.378 3.074-6.6-10.839-1.141-22.243-5.378-22.243-24.283 0-5.378 1.94-9.778 5.014-13.2-.485-1.222-2.184-6.275.486-13.038 0 0 4.125-1.304 13.426 5.052a46.97 46.97 0 0 1 12.214-1.63c4.125 0 8.33.571 12.213 1.63 9.302-6.356 13.427-5.052 13.427-5.052 2.67 6.763.97 11.816.485 13.038 3.155 3.422 5.015 7.822 5.015 13.2 0 18.905-11.404 23.06-22.324 24.283 1.78 1.548 3.316 4.481 3.316 9.126 0 6.6-.08 11.897-.08 13.526 0 1.304.89 2.853 3.316 2.364 19.412-6.52 33.405-24.935 33.405-46.691C97.707 22 75.788 0 48.854 0z"/></svg>
              </a>

              <a href="https://field.gurworks.com" target="_blank" class="block w-7 h-7 rounded-full overflow-hidden border border-gray-600 hover:border-[#e3ded1] transition-colors group relative">
                 <img src={~p"/images/gur.png"} alt="Gur" class="w-full h-full object-cover grayscale group-hover:grayscale-0 transition-all duration-500" />
              </a>
            </div>
            
            <span class="hidden md:block text-[7px] text-gray-500 uppercase font-bold tracking-wider opacity-60 hover:opacity-100 transition-opacity cursor-default">Created by gur</span>
          </div>
      </div>

      <!-- Canvas Strip -->
      <div id="jam-session" 
           phx-hook="JamSession" 
           data-base-time={@base_time} 
           data-zoom-x={@zoom_x}
           data-zoom-y={@zoom_y}
           data-user-color={@user_color}
           data-waveform={@waveform}
           class="flex-grow w-full relative overflow-hidden select-none cursor-crosshair shadow-[0_10px_40px_rgba(0,0,0,0.6)] z-10 touch-none"
           style={"
             background-color: #f0eee6;
             background-image: 
               linear-gradient(rgba(0,0,0,0.03) 1px, transparent 1px),
               linear-gradient(90deg, rgba(0,0,0,0.03) 1px, transparent 1px);
             background-size: #{@grid_spacing}px 20px;
             background-position: 0 calc(50% - 1px);
           "}>
        
        <!-- Time Bar (Center) -->
        <div class="absolute left-1/2 top-0 bottom-0 w-[2px] bg-red-800/30 z-20 pointer-events-none mix-blend-multiply"></div>
        
        <!-- Center Pitch Line -->
        <div class="absolute left-0 right-0 top-1/2 h-[1px] bg-gray-400/20 z-0 pointer-events-none"></div>
        
        <!-- Clock Display -->
        <div id="clock-display" class="absolute left-1/2 top-4 -translate-x-1/2 z-20 font-mono text-gray-500 text-lg tracking-widest opacity-60">
          00:00:00
        </div>

        <!-- Canvas Content -->
        <div id="canvas-content" 
             class="absolute top-0 bottom-0 left-1/2 will-change-transform origin-left">
          <div id="optimistic-notes" phx-update="ignore" class="absolute inset-0 z-10 pointer-events-none"></div>
          <div :for={note <- @notes} 
               id={"note-#{note.id}"}
               data-x={note.x}
               data-y={note.y}
               data-color={note.color}
               data-waveform={Map.get(note, :waveform, "sine")}
               class={"absolute note-item shadow-sm opacity-90 mix-blend-multiply " <> (
                 case Map.get(note, :waveform, "sine") do
                   "sine" -> "rounded-full"
                   "square" -> "rounded-none"
                   _ -> ""
                 end
               )}
               style={"left: #{(note.x - @base_time) * @zoom_x}px; top: calc(50% + #{note.y * @zoom_y}px); width: 12px; height: 12px; background-color: #{note.color}; transform: translate(-50%, -50%); " <> (
                 case Map.get(note, :waveform, "sine") do
                   "triangle" -> "clip-path: polygon(50% 0%, 0% 100%, 100% 100%);"
                   "sawtooth" -> "clip-path: polygon(0% 100%, 100% 0%, 100% 100%);"
                   _ -> ""
                 end
               )}>
          </div>
        </div>
        
        <!-- Click Overlay for Drawing -->
        <div id="click-overlay" class="absolute inset-0 z-10 touch-none"></div>
        
        <!-- Cursors Container -->
        <div id="cursors-container" phx-update="ignore" class="absolute inset-0 z-30 pointer-events-none overflow-hidden"></div>
      </div>
      
      <!-- Controls Panel (Bottom Surface) -->
      <div class="flex-none h-20 w-full bg-[#2c2c2c] z-20">
        <div class="flex flex-row items-center justify-center px-4 md:px-8 h-full max-w-[1600px] mx-auto">
          
          <!-- Compact Controls -->
          <div class="flex items-center gap-2 md:gap-6 bg-[#363636] px-3 md:px-6 py-2 rounded-full shadow-lg border border-[#444] scale-90 md:scale-100 origin-bottom">
            <form phx-change="update_settings" onsubmit="return false;" class="flex items-center gap-2 md:gap-6">
              
              <!-- Waveform Selector -->
              <div class="flex flex-col items-center gap-1.5 border-r border-[#555] pr-2 md:pr-6 mr-0 md:mr-0">
                <div class="flex gap-1">
                  <%= for shape <- ["sine", "square", "triangle", "sawtooth"] do %>
                    <label class={"cursor-pointer p-1.5 rounded hover:bg-white/10 transition-colors " <> (if @waveform == shape, do: "bg-white/20 text-white", else: "text-gray-500")}>
                      <input type="radio" name="waveform" value={shape} class="hidden" checked={@waveform == shape} />
                      <div class={
                        cond do
                           shape == "sine" -> "w-3 h-3 rounded-full bg-current"
                           shape == "square" -> "w-3 h-3 bg-current"
                           shape == "triangle" -> "w-0 h-0 border-l-[6px] border-l-transparent border-r-[6px] border-r-transparent border-b-[12px] border-b-current scale-75"
                           shape == "sawtooth" -> "w-3 h-3 bg-current"
                           true -> ""
                        end
                      } style={if shape == "sawtooth", do: "clip-path: polygon(0% 100%, 100% 0%, 100% 100%);"} title={String.capitalize(shape)}></div>
                    </label>
                  <% end %>
                </div>
                <span class="text-[8px] text-gray-500 uppercase font-bold tracking-wider hidden sm:inline-block">Brush</span>
              </div>

              <!-- Zoom X -->
              <div class="flex flex-col items-center gap-1.5" title={"Time Scale: #{Float.round(@zoom_x, 3)}"}>
                <input type="range" name="zoom_x" min="0.01" max="0.5" step="0.001" value={@zoom_x} 
                       class="w-16 h-1 bg-gray-700 rounded-lg appearance-none cursor-pointer accent-[#e3ded1] hover:accent-white transition-all"/>
                <span class="text-[8px] text-gray-500 uppercase font-bold tracking-wider">Time</span>
              </div>
  
              <!-- Zoom Y -->
              <div class="flex flex-col items-center gap-1.5" title={"Pitch Scale: #{Float.round(@zoom_y, 2)}"}>
                <input type="range" name="zoom_y" min="0.5" max="2.0" step="0.01" value={@zoom_y}
                       class="w-16 h-1 bg-gray-700 rounded-lg appearance-none cursor-pointer accent-[#e3ded1] hover:accent-white transition-all"/>
                <span class="text-[8px] text-gray-500 uppercase font-bold tracking-wider whitespace-nowrap">Pitch</span>
              </div>
  
              <!-- Volume -->
              <div class="flex flex-col items-center gap-1.5" title={"Volume: #{@volume} dB"}>
                <input type="range" name="volume" min="-30" max="0" step="1" value={@volume}
                       id="volume-slider"
                       class="w-16 h-1 bg-gray-700 rounded-lg appearance-none cursor-pointer accent-[#e3ded1] hover:accent-white transition-all"/>
                <span class="text-[8px] text-gray-500 uppercase font-bold tracking-wider">Vol</span>
              </div>
            </form>
  
            <div class="w-px h-8 bg-[#555]"></div>
  
            <button id="audio-toggle" class="flex flex-col items-center gap-1.5 text-[#e3ded1] hover:text-white transition-colors focus:outline-none group" title="Toggle Audio">
              <.icon name="hero-speaker-wave" class="size-5 mb-1" />
              <span id="audio-status-text" class="sr-only">Start Audio</span>
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def handle_info({:new_note, note}, socket) do
    {:noreply, update(socket, :notes, fn notes -> [note | notes] end)}
  end

  def handle_info(%{event: "presence_diff", payload: _diff}, socket) do
    users = Presence.list("jam:presence")
    {:noreply, assign(socket, :users, users)}
  end

  def handle_info(%{event: "cursor_move", payload: payload}, socket) do
    {:noreply, push_event(socket, "cursor_move", payload)}
  end

  def handle_event("cursor_move", %{"dt" => dt, "dy" => dy}, socket) do
    V2Web.Endpoint.broadcast_from!(self(), "jam:presence", "cursor_move", %{
      user_id: socket.assigns.user_id,
      dt: dt,
      dy: dy,
      color: socket.assigns.user_color
    })
    {:noreply, socket}
  end

  def handle_event("add_note", %{"x" => x, "y" => y}, socket) do
    stored_y = y / socket.assigns.zoom_y
    waveform = socket.assigns.waveform
    Canvas.add_note(x, stored_y, socket.assigns.user_color, waveform)
    {:noreply, socket}
  end

  def handle_event("update_settings", %{"zoom_x" => zoom_x, "zoom_y" => zoom_y, "volume" => vol} = params, socket) do
    {zx, _} = Float.parse(zoom_x)
    {zy, _} = Float.parse(zoom_y)
    {v, _} = Float.parse(vol)
    
    waveform = params["waveform"] || socket.assigns.waveform || "sine"
    
    {:noreply, assign(socket, zoom_x: zx, zoom_y: zy, volume: v, waveform: waveform)}
  end
  
  def handle_event("update_zoom_x", %{"value" => val}, socket) do
    # Handle pinch zoom from JS pushEvent
    {zoom, _} = Float.parse(val)
    {:noreply, assign(socket, zoom_x: zoom)}
  end
end
