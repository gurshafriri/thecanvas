# The Canvas (WIP)

<p align="center">
  <img src="https://github.com/user-attachments/assets/62c56bcc-6a7b-4a54-a67a-83cf1e2487fa"
       alt="the canvas"
       width="60%" />
</p>

**The Canvas** is a real-time, collaborative musical interface where sound meets visualization. It allows multiple users to jump into a shared infinite canvas, place notes, and create music together in the browser.

*The canvas pilot is live on https://canvas.gurworks.com*

## About

The purpose of this tool is to provide a shared digital space for musical experimentation. It treats music creation as a visual and spatial experience:

*   **Collaborative Jamming**: See other players' cursors and notes in real-time.
*   **Infinite Canvas**: A continuous timeline where you can place notes freely.
*   **Sound Synthesis**: Draw notes with different waveforms (Sine, Square, Triangle, Sawtooth) to shape the texture of the sound.
*   **Interactive Controls**: Zoom in/out of time and pitch to explore details or see the bigger picture.

## Tech Stack

Built for high-performance real-time interaction:

*   **Elixir** & **Phoenix** (v1.8+)
*   **LiveView** for real-time state synchronization
*   **Phoenix Presence** for multiplayer features
*   **Tailwind CSS** (v4) for styling
*   **Esbuild** for asset bundling

## Running localy

To start the Phoenix server locally:

1.  **Install dependencies**:
    ```bash
    mix setup
    ```

2.  **Start the server**:
    ```bash
    mix phx.server
    ```

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

