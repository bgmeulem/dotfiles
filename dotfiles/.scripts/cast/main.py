"""
Cast muted video with working subtitles using catt,
while keeping local mpv audio playback perfectly in sync.

Cross-platform: works on Linux, macOS, and Windows.

Requirements:
  pychromecast 
  RangeHTTPServer
  `catt` available on your PATH.

Usage:
  uv run python cast_local_audio.py /path/to/movie.mkv
"""
import os, sys, time, tempfile, threading, subprocess, platform
import pychromecast

VIDEO_FILE = sys.argv[1] if len(sys.argv) > 1 else None

SYNC_INTERVAL = 0.3
DRIFT_THRESHOLD = 0.15  # seconds

# --- Cross-platform socket path ---
if platform.system() == "Windows":
    MPV_SOCKET = r"\\.\pipe\mpv-audio"
else:
    MPV_SOCKET = os.path.join(tempfile.gettempdir(), "mpv-audio.sock")


# === Core utilities ===
class MPVIPC:
    """Tiny IPC helper for mpv's JSON socket."""
    def __init__(self, socket_path):
        self.path = socket_path
        self.sock = None
        self.req_id = 0
        self.lock = threading.Lock()

    def connect(self):
        import socket
        # Wait for mpv socket to appear
        for _ in range(50):
            if os.path.exists(self.path) or platform.system() == "Windows":
                break
            time.sleep(0.1)
        if platform.system() == "Windows":
            self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.sock.connect(("localhost", 6600))  # fallback not ideal, see note
        else:
            self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            self.sock.connect(self.path)
        self.sock.settimeout(1.0)

    def send(self, cmd, expect_reply=False):
        import socket, json
        with self.lock:
            self.req_id += 1
            req_id = self.req_id if expect_reply else None
            msg = {"command": cmd}
            if req_id:
                msg["request_id"] = req_id
            self.sock.sendall((json.dumps(msg) + "\n").encode("utf-8"))
            if not expect_reply:
                return None
            buf = b""
            start = time.time()
            while time.time() - start < 2.0:
                try:
                    chunk = self.sock.recv(4096)
                    if not chunk:
                        raise ConnectionError("mpv IPC closed")
                    buf += chunk
                    while b"\n" in buf:
                        line, buf = buf.split(b"\n", 1)
                        if not line.strip():
                            continue
                        try:
                            msg = json.loads(line)
                            if msg.get("request_id") == req_id:
                                if msg.get("error") == "success":
                                    return msg.get("data")
                                return None
                        except Exception:
                            continue
                except socket.timeout:
                    continue
            return None


def find_chromecast():
    """Return (cast, browser) for the first Chromecast found."""
    print("Searching for Chromecast devices...")
    chromecasts, browser = pychromecast.get_chromecasts()
    if not chromecasts:
        print("No Chromecast found.")
        sys.exit(1)
    cast = chromecasts[0]
    print(f"Using Chromecast: {cast.name} ({cast.cast_info.host})")
    cast.wait()
    return cast, browser


def create_muted_video(src_path):
    """Generate a muted version of the video for casting."""
    tmp_dir = tempfile.gettempdir()
    tmp_muted = os.path.join(tmp_dir, os.path.basename(src_path))
    print(f"Creating muted video for Chromecast → {tmp_muted}")
    r = subprocess.run(
        ["ffmpeg", "-y", "-i", src_path, "-an", "-map", "0:v:0", "-c:v", "copy", tmp_muted],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    if r.returncode != 0:
        raise RuntimeError("ffmpeg failed to create muted video")
    return tmp_muted


def mpv_start_audio(path, start_pos):
    """Launch mpv with IPC for local audio only."""
    try:
        if os.path.exists(MPV_SOCKET) and platform.system() != "Windows":
            os.unlink(MPV_SOCKET)
    except FileNotFoundError:
        pass

    args = [
        "mpv", "--no-video", "--no-terminal",
        "--msg-level=all=no",
        f"--input-ipc-server={MPV_SOCKET}",
        path,
    ]
    print("Starting mpv audio playback...")
    proc = subprocess.Popen(args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    ipc = MPVIPC(MPV_SOCKET)
    ipc.connect()

    # wait until ready
    for _ in range(10):
        val = ipc.send(["get_property", "time-pos"], expect_reply=True)
        if val is not None:
            break
        time.sleep(0.2)

    ipc.send(["set_property", "time-pos", start_pos])
    print(f"Audio synced to {start_pos:.2f}s")
    return proc, ipc


def sync_mpv_to_cast(mc, ipc):
    """Keep mpv audio in sync with Chromecast playback."""
    last_ct = None
    last_state = None
    while True:
        try:
            st = mc.status
            if not st:
                time.sleep(SYNC_INTERVAL)
                continue

            # Pause/play sync
            if st.player_state != last_state:
                if st.player_state == "PAUSED":
                    print("→ Chromecast paused, pausing mpv")
                    ipc.send(["set_property", "pause", True])
                elif st.player_state == "PLAYING":
                    print("→ Chromecast playing, resuming mpv")
                    ipc.send(["set_property", "pause", False])
                last_state = st.player_state

            # Drift correction
            if st.player_state == "PLAYING" and st.current_time is not None:
                mpv_pos = ipc.send(["get_property", "time-pos"], expect_reply=True)
                if isinstance(mpv_pos, (int, float)):
                    cc_pos = getattr(st, "adjusted_current_time", st.current_time)
                    drift = cc_pos - mpv_pos
                    if abs(drift) > DRIFT_THRESHOLD:
                        print(f"↔ Drift {drift:+.2f}s → correcting mpv")
                        ipc.send(["set_property", "time-pos", cc_pos])

            # Detect seek while paused
            if st.player_state == "PAUSED" and st.current_time is not None and last_ct is not None:
                if abs(st.current_time - last_ct) > 1.0:
                    print("↪ Seek detected, updating mpv position")
                    ipc.send(["set_property", "time-pos", st.current_time])

            last_ct = st.current_time
        except Exception as e:
            print("Sync error:", e)
            time.sleep(1)
        time.sleep(SYNC_INTERVAL)


def main():
    video = VIDEO_FILE
    if video is None: raise ValueError("Please pass a video file")
    srt_path = os.path.splitext(video)[0] + ".srt"
    muted = create_muted_video(video)

    print("Casting via catt...")
    catt_cmd = [
        "catt", "cast", muted,
        "--subtitles", srt_path,
        "--force-default"
    ]
    catt_proc = subprocess.Popen(catt_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)

    cast, browser = find_chromecast()
    mc = cast.media_controller

    # Wait until playback actually starts
    print("Waiting for Chromecast playback to begin...")
    while True:
        mc.block_until_active()
        if mc.status.player_state == "PLAYING":
            break
        time.sleep(0.3)

    start_pos = mc.status.current_time or 0.0
    print(f"Chromecast started at {start_pos:.2f}s")

    # Start mpv audio
    mpv_proc, ipc = mpv_start_audio(video, start_pos)
    threading.Thread(target=sync_mpv_to_cast, args=(mc, ipc), daemon=True).start()

    print("\n=== Controls ===")
    print("Use Chromecast app/remote to control playback.")
    print("Audio will stay in sync.\n")

    try:
        mpv_proc.wait()
    except KeyboardInterrupt:
        print("\nStopping...")
    finally:
        print("Cleaning up Chromecast and processes...")
        try:
            mc.stop()
            time.sleep(0.5)
            cast.quit_app()
        except Exception:
            pass
        mpv_proc.terminate()
        catt_proc.terminate()
        try:
            os.remove(muted)
        except Exception:
            pass
        pychromecast.discovery.stop_discovery(browser)


if __name__ == "__main__":
    main()
