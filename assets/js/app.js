// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

let Hooks = {}

Hooks.JamSession = {
  mounted() {
    // Create synths for each waveform
    this.synths = {
      sine: new Tone.PolySynth(Tone.Synth, { 
        oscillator: { type: "sine" },
        volume: 0,
        envelope: {
          attack: 0.1,
          decay: 0.2,
          sustain: 0.5,
          release: 1
        }
      }).toDestination(),
      square: new Tone.PolySynth(Tone.Synth, { 
        oscillator: { type: "square" },
        volume: -10
      }).toDestination(),
      triangle: new Tone.PolySynth(Tone.Synth, { oscillator: { type: "triangle" } }).toDestination(),
      sawtooth: new Tone.PolySynth(Tone.Synth, { 
        oscillator: { type: "sawtooth" },
        volume: -10
      }).toDestination()
    };
    
    this.audioStarted = false;
    this.notes = new Map(); 
    
    // Read base time from data attribute
    this.baseTime = parseInt(this.el.dataset.baseTime);
    this.clockEl = document.getElementById("clock-display");

    // Sync initial notes
    this.syncNotes();

    // Animation Loop
    this.tick = () => {
      const now = Date.now();
      const speed = parseFloat(this.el.dataset.zoomX) || 0.1;
      const zoomY = parseFloat(this.el.dataset.zoomY) || 1.0;
      
      // Update Clock
      if(this.clockEl) {
          // Show ms for tech feel? No, standard time is cleaner
          this.clockEl.innerText = new Date(now).toLocaleTimeString();
      }
      
      // Update visual scroll
      const content = document.getElementById("canvas-content");
      if(content) {
        const offset = (now - this.baseTime) * speed;
        content.style.transform = `translate3d(-${offset}px, 0, 0)`;
      }

      // Playback check
      if (this.audioStarted) {
        this.checkPlayback(now);
      }

      requestAnimationFrame(this.tick);
    }
    requestAnimationFrame(this.tick);

    // Cursor Tracking
    this.cursorContainer = document.getElementById("cursors-container");
    this.cursors = new Map();

    this.handleEvent("cursor_move", ({user_id, dt, dy, color}) => {
        let cursor = this.cursors.get(user_id);
        if (!cursor) {
            cursor = document.createElement("div");
            cursor.className = "absolute pointer-events-none transition-transform duration-100 ease-linear z-50 opacity-60";
            cursor.innerHTML = `
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg" class="transform -rotate-0">
                <path d="M3 3L10.07 19.97L12.58 12.58L19.97 10.07L3 3Z" fill="${color}" stroke="white" stroke-width="1" stroke-linejoin="round"/>
              </svg>
            `;
            if(this.cursorContainer) this.cursorContainer.appendChild(cursor);
            this.cursors.set(user_id, cursor);
        }
        
        // Store world-coordinates for this cursor
        cursor.dt = dt;
        cursor.dy = dy;
        
        // Initial update (will be smoothed by tick loop if we implemented one, but direct update is fine for now)
        // Actually, we need to calculate screen X/Y here based on OUR zoom
        const mySpeed = parseFloat(this.el.dataset.zoomX) || 0.1;
        const myZoomY = parseFloat(this.el.dataset.zoomY) || 1.0;
        
        const rect = this.el.getBoundingClientRect(); // JamSession container
        const centerX = rect.width / 2;
        const centerY = rect.height / 2;

        const screenX = centerX + (dt * mySpeed);
        const screenY = centerY + (dy * myZoomY);

        cursor.style.transform = `translate(${screenX}px, ${screenY}px)`;
        cursor.style.opacity = "0.6"; 
        
        // Auto-remove if no updates for 10s (inactive)
        if (cursor.timeout) clearTimeout(cursor.timeout);
        cursor.timeout = setTimeout(() => {
            cursor.remove();
            this.cursors.delete(user_id);
        }, 10000);
    });

    // Listeners
    this.setAudioState = (enabled) => {
        this.audioStarted = enabled;
        const toggleBtn = document.getElementById("audio-toggle");
        const status = document.getElementById("audio-status-text");
        
        if (enabled) {
             if(toggleBtn) {
                toggleBtn.classList.remove("text-[#e3ded1]", "hover:text-white");
                toggleBtn.classList.add("text-green-400", "hover:text-green-300");
             }
             if(status) status.innerText = "Mute";
        } else {
             if(toggleBtn) {
                toggleBtn.classList.add("text-[#e3ded1]", "hover:text-white");
                toggleBtn.classList.remove("text-green-400", "hover:text-green-300");
             }
             if(status) status.innerText = "Start Audio";
        }
    };

    const toggleBtn = document.getElementById("audio-toggle");
    if(toggleBtn) {
      toggleBtn.addEventListener("click", async () => {
        await Tone.start();
        this.setAudioState(!this.audioStarted);
      });
    }
    
    // Volume Control
    const volSlider = document.getElementById("volume-slider");
    if(volSlider) {
        volSlider.addEventListener("input", (e) => {
            const val = parseFloat(e.target.value);
            for (const [type, synth] of Object.entries(this.synths)) {
                let offset = 0;
                if (type === "square") offset = -10;
                if (type === "sawtooth") offset = -10;
                synth.volume.value = val + offset;
            }
        });
    }
    
    // Pinch Zoom Handler (Trackpad)
    this.el.addEventListener("wheel", (e) => {
        if (e.ctrlKey) {
            e.preventDefault();
            const currentZoom = parseFloat(this.el.dataset.zoomX) || 0.1;
            // Use deltaY. Negative means zoom in (pinch out)
            const delta = -e.deltaY * 0.001; 
            const newZoom = Math.max(0.01, Math.min(0.5, currentZoom + delta));
            
            // Throttle? For MVP we just push
            this.pushEvent("update_zoom_x", {value: newZoom});
        }
    }, {passive: false});

    const overlay = document.getElementById("click-overlay");
    if(overlay) {
        // Cursor tracking
        let lastCursorTime = 0;
        const cursorThrottle = 50;

        overlay.addEventListener("mousemove", (e) => {
            const now = Date.now();
            if (now - lastCursorTime > cursorThrottle) {
                 const rect = overlay.getBoundingClientRect();
                 const centerX = rect.width / 2;
                 const centerY = rect.height / 2;
                 
                 // Calculate deltas from center
                 const deltaX = e.clientX - (rect.left + centerX);
                 const deltaY = e.clientY - (rect.top + centerY);
                 
                 // Normalize to World Coords
                 // dt = pixels / speed
                 // dy = pixels / zoomY
                 const speed = parseFloat(this.el.dataset.zoomX) || 0.1;
                 const zoomY = parseFloat(this.el.dataset.zoomY) || 1.0;
                 
                 const dt = deltaX / speed;
                 const dy = deltaY / zoomY;
                 
                 this.pushEvent("cursor_move", {dt, dy});
                 lastCursorTime = now;
            }
        });

        let isDrawing = false;
        let lastDrawTime = 0;
        const throttleMs = 50; // Limit note creation speed

        const addNoteAt = (e) => {
            const rect = e.target.getBoundingClientRect();
            const centerX = rect.width / 2;
            // const clickX = e.clientX; 
            
            const containerCenterScreenX = rect.left + rect.width / 2;
            const deltaPixels = e.clientX - containerCenterScreenX;
            
            const speed = parseFloat(this.el.dataset.zoomX) || 0.1;
            const now = Date.now();
            const deltaMs = deltaPixels / speed;
            const timestamp = Math.floor(now + deltaMs);
            
            // Center-based Y logic
            // e.clientY is viewport Y
            // Center of container in viewport Y
            const containerCenterScreenY = rect.top + rect.height / 2;
            const deltaY = e.clientY - containerCenterScreenY;
            
            // Optimistic UI Update
            const zoomY = parseFloat(this.el.dataset.zoomY) || 1.0;
            const storedY = deltaY / zoomY;
            const tempId = `temp-${timestamp}`;
            const userColor = this.el.dataset.userColor || "#ccc";
            const waveform = this.el.dataset.waveform || "sine";

            // 1. Add to internal map for playback
            this.notes.set(tempId, {
                id: tempId,
                x: timestamp,
                y: storedY,
                played: false,
                isOptimistic: true,
                color: userColor,
                waveform: waveform
            });

            // 2. Create DOM element
            const optContainer = document.getElementById("optimistic-notes");
            if (optContainer) {
                const el = document.createElement("div");
                el.id = `opt-note-${tempId}`;
                el.className = "absolute note-item shadow-sm opacity-90 mix-blend-multiply";
                
                // Apply styles based on waveform (mirroring server logic)
                if (waveform === "sine") el.classList.add("rounded-full");
                else if (waveform === "square") el.classList.add("rounded-none");
                
                if (waveform === "triangle") el.style.clipPath = "polygon(50% 0%, 0% 100%, 100% 100%)";
                else if (waveform === "sawtooth") el.style.clipPath = "polygon(0% 100%, 100% 0%, 100% 100%)";

                // Match server styling
                const left = (timestamp - this.baseTime) * speed;
                el.style.left = `${left}px`;
                el.style.top = `calc(50% + ${deltaY}px)`; // deltaY is (storedY * zoomY)
                el.style.width = "12px";
                el.style.height = "12px";
                el.style.backgroundColor = userColor;
                el.style.transform = "translate(-50%, -50%)";
                
                // Add to container
                optContainer.appendChild(el);
            }

            // We send the raw pixel offset from center. 
            // The server divides by zoom_y to store the "base" offset.
            this.pushEvent("add_note", {x: timestamp, y: deltaY}); 
        };

        overlay.addEventListener("pointerdown", async (e) => {
            if (!this.audioStarted) {
                await Tone.start();
                this.setAudioState(true);
            }

            isDrawing = true;
            overlay.setPointerCapture(e.pointerId);
            addNoteAt(e);
            
            // Continue cursor updates while dragging
            const rect = overlay.getBoundingClientRect();
            const centerX = rect.width / 2;
            const centerY = rect.height / 2;
            
            const deltaX = e.clientX - (rect.left + centerX);
            const deltaY = e.clientY - (rect.top + centerY);
            
            const speed = parseFloat(this.el.dataset.zoomX) || 0.1;
            const zoomY = parseFloat(this.el.dataset.zoomY) || 1.0;
            
            const dt = deltaX / speed;
            const dy = deltaY / zoomY;
            
            this.pushEvent("cursor_move", {dt, dy});
        });

        overlay.addEventListener("pointermove", (e) => {
             const now = Date.now();
             
             // Always update cursor even if drawing
             if (now - lastCursorTime > cursorThrottle) {
                 const rect = overlay.getBoundingClientRect();
                 const centerX = rect.width / 2;
                 const centerY = rect.height / 2;
                 
                 const deltaX = e.clientX - (rect.left + centerX);
                 const deltaY = e.clientY - (rect.top + centerY);
                 
                 const speed = parseFloat(this.el.dataset.zoomX) || 0.1;
                 const zoomY = parseFloat(this.el.dataset.zoomY) || 1.0;
                 
                 const dt = deltaX / speed;
                 const dy = deltaY / zoomY;
                 
                 this.pushEvent("cursor_move", {dt, dy});
                 lastCursorTime = now;
            }
        
            if (!isDrawing) return;
            if (now - lastDrawTime > throttleMs) {
                addNoteAt(e);
                lastDrawTime = now;
            }
        });

        overlay.addEventListener("pointerup", (e) => {
            isDrawing = false;
            overlay.releasePointerCapture(e.pointerId);
        });
        
        overlay.addEventListener("pointerleave", (e) => {
             // Optional: stop drawing if left? But pointer capture handles this usually.
        });
    }
    
    this.handleEvent("new_note", ({note}) => {
        this.notes.set(note.id, {
            id: note.id,
            x: note.x,
            y: note.y,
            played: false,
            waveform: note.waveform
        });
    });
  },
  
  updated() {
     this.syncNotes();
  },

  syncNotes() {
     const els = document.querySelectorAll("#canvas-content > .note-item");
     els.forEach(el => {
         const id = parseInt(el.id.replace("note-", ""));
         const x = parseInt(el.dataset.x);
         const y = parseFloat(el.dataset.y);
         const waveform = el.dataset.waveform || "sine";

         if(!this.notes.has(id)) {
             // New real note found. Check for optimistic match.
             let matchKey = null;
             for (const [key, val] of this.notes) {
                 if (val.isOptimistic && val.x === x) {
                     // We assume timestamp x is unique enough for this user in this session
                     matchKey = key;
                     break;
                 }
             }

             let played = false;
             if (matchKey) {
                 // Inherit played state
                 played = this.notes.get(matchKey).played;
                 // Cleanup optimistic note
                 this.notes.delete(matchKey);
                 const optEl = document.getElementById(`opt-note-${matchKey}`);
                 if(optEl) optEl.remove();
             }

             this.notes.set(id, {
                 id: id,
                 x: x,
                 y: y,
                 played: played,
                 waveform: waveform
             });
         }
     });
  },
  
  checkPlayback(now) {
      const lookahead = 100;
      for (const [id, note] of this.notes) {
          if (note.x < now - 5000) {
              this.notes.delete(id);
              continue;
          }
          if (note.played) continue;
          
          if (note.x <= now + lookahead && note.x >= now - 100) {
              // Pitch Logic (Centered at 0 = Midi 69 A4)
              // 16.66 pixels per semitone roughly matches the old 1000px/60st range
              const pixelsPerSemitone = 16.66;
              const centerMidi = 69; // A4
              
              // note.y is offset from center. Positive is DOWN (lower pitch)
              const semitoneOffset = note.y / pixelsPerSemitone;
              const midi = centerMidi - semitoneOffset;
              
              const freq = Tone.Frequency(midi, "midi");
              
              const time = Tone.now() + (note.x - now) / 1000;
              
              const synth = this.synths[note.waveform] || this.synths["sine"];
              synth.triggerAttackRelease(freq, "8n", time);
              note.played = true;
              
              const el = document.getElementById(`note-${note.id}`);
              if(el) {
                  el.style.transform = "translate(-50%, -50%) scale(1.5)";
                  setTimeout(() => {
                      if(el) el.style.transform = "translate(-50%, -50%) scale(1)";
                  }, 200);
              }
          }
      }
  }
}

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: Hooks
})

topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

liveSocket.connect()
window.liveSocket = liveSocket
