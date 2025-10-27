Cast muted video with working subtitles using catt,
while keeping local mpv audio playback perfectly in sync.

Cross-platform: works on Linux, macOS, and Windows.

Requirements:
  pychromecast 
  RangeHTTPServer
  `catt` available on your PATH.

Usage:
  uv run python main.py /path/to/movie.mkv
