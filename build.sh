#!/usr/bin/env bash
# Regenerate HTML (and optionally PDF) from the Markdown source.
# Requirements: pandoc >= 3.x, Google Chrome (macOS path shown; adjust for Linux/Windows)
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
MD="$DIR/CSW-F5-Integration-Guide.md"
HTML="$DIR/CSW-F5-Integration-Guide.html"
PDF="$DIR/CSW-F5-Integration-Guide.pdf"

# Detect Chrome (macOS / Linux)
if [[ -f "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" ]]; then
  CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
elif command -v google-chrome &>/dev/null; then
  CHROME="google-chrome"
elif command -v chromium-browser &>/dev/null; then
  CHROME="chromium-browser"
else
  echo "Warning: Chrome not found — PDF will not be generated."
  CHROME=""
fi

CSS='
*,*::before,*::after{box-sizing:border-box;margin:0;padding:0}
body{font-family:"Helvetica Neue",Arial,sans-serif;font-size:14px;line-height:1.65;color:#1a1a2e;background:#fff;max-width:960px;margin:0 auto;padding:48px 56px}
body::before{content:"";display:block;height:6px;background:linear-gradient(90deg,#00205b 0%,#007bc7 60%,#00bceb 100%);margin:-48px -56px 40px -56px}
h1{font-size:26px;font-weight:700;color:#00205b;border-bottom:3px solid #007bc7;padding-bottom:10px;margin-bottom:8px}
h1+p{color:#555;font-size:13px;margin-bottom:32px}
h2{font-size:18px;font-weight:700;color:#007bc7;margin:36px 0 12px;padding-bottom:4px;border-bottom:1px solid #cce4f6}
h3{font-size:15px;font-weight:700;color:#00205b;margin:24px 0 8px}
h4{font-size:13.5px;font-weight:700;color:#555;margin:18px 0 6px;text-transform:uppercase;letter-spacing:.04em}
p{margin-bottom:12px}
blockquote{background:#f0f7ff;border-left:4px solid #007bc7;border-radius:0 4px 4px 0;padding:10px 16px;margin:16px 0;color:#1a4a7a;font-size:13px}
blockquote p{margin:0 0 6px}blockquote p:last-child{margin:0}
table{width:100%;border-collapse:collapse;margin:16px 0 24px;font-size:13px}
thead tr{background:#00205b;color:#fff}
thead th{padding:9px 12px;text-align:left;font-weight:600}
tbody tr:nth-child(even){background:#f5f8fc}
td{padding:8px 12px;border-bottom:1px solid #dde6ef;vertical-align:top}
pre{background:#0d1117;color:#c9d1d9;border-radius:6px;padding:16px 20px;overflow-x:auto;font-size:12.5px;line-height:1.5;margin:16px 0 24px}
code{font-family:"SFMono-Regular",Consolas,"Liberation Mono",Menlo,monospace}
p>code,li>code,td>code{background:#eef2f8;color:#b52c2c;border-radius:3px;padding:1px 5px;font-size:12.5px}
ul,ol{margin:8px 0 16px 24px}li{margin-bottom:5px}
ul.task-list{list-style:none;margin-left:0}ul.task-list li{padding-left:22px;position:relative}ul.task-list li input[type="checkbox"]{position:absolute;left:0;top:2px}
hr{border:none;border-top:1px solid #cce4f6;margin:32px 0}
a{color:#007bc7;text-decoration:none}a:hover{text-decoration:underline}
img{display:block;max-width:100%;margin:20px auto 6px;border:1px solid #cce4f6;border-radius:6px;box-shadow:0 2px 12px rgba(0,0,0,.12)}
img+em{display:block;text-align:center;font-size:12px;color:#666;margin-bottom:24px}
.yt-wrap{position:relative;padding-bottom:56.25%;height:0;overflow:hidden;border-radius:8px;box-shadow:0 4px 20px rgba(0,0,0,.18);margin:20px 0 28px}
.yt-wrap iframe{position:absolute;top:0;left:0;width:100%;height:100%;border:0;border-radius:8px}
.yt-pdf-box{display:none;background:#00205b;color:#fff;border-radius:8px;padding:18px 22px;margin:20px 0 28px}
.yt-pdf-box .yt-title{font-size:15px;font-weight:700;margin-bottom:6px}
.yt-pdf-box .yt-url{font-size:13px;color:#7dd3fc;word-break:break-all}
.yt-pdf-box .yt-meta{font-size:12px;color:#93c5fd;margin-top:4px}
@media print{body{padding:0;font-size:12px}pre{white-space:pre-wrap;word-break:break-all}img{box-shadow:none}.yt-wrap{display:none!important}.yt-pdf-box{display:block!important}@page{margin:20mm 18mm;size:A4}}
'

echo "Building HTML..."
echo "$CSS" | pandoc "$MD" \
  --standalone \
  --embed-resources \
  --metadata title="Cisco Secure Workload — F5 BIG-IP Integration Guide" \
  --css /dev/stdin \
  -o "$HTML"

# Remove the duplicate pandoc-generated title block (the markdown h1 is the real title)
python3 -c "
import sys, re
path = sys.argv[1]
html = open(path).read()
html = re.sub(r'<header[^>]*id=\"title-block-header\"[^>]*>.*?</header>\n?', '', html, flags=re.DOTALL)
open(path, 'w').write(html)
" "$HTML"

# Inject a responsive YouTube iframe after the IPFIX walkthrough link in the video table
python3 - "$HTML" << 'PY'
import sys, re
path = sys.argv[1]
html = open(path).read()
YT_ID = "aJZEcZtUXDg"
YT_URL = f"https://www.youtube.com/watch?v={YT_ID}"
EMBED_URL = f"https://www.youtube-nocookie.com/embed/{YT_ID}?rel=0&modestbranding=1"
iframe_block = f"""
<div class="yt-wrap">
  <iframe src="{EMBED_URL}" title="Cisco Tetration and F5 BIG-IP IPFIX Configuration"
    allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
    referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>
</div>
<div class="yt-pdf-box">
  <div class="yt-title">&#9654; Video: F5 BIG-IP IPFIX Configuration for Secure Workload</div>
  <div class="yt-url">{YT_URL}</div>
  <div class="yt-meta">See §10 for all F5 video walkthroughs &middot; Open in browser to watch</div>
</div>"""
# Insert the iframe right after the closing </table> of the video table (the table that contains the IPFIX link)
m = re.search(r'(<table>(?:(?!</table>).)*?aJZEcZtUXDg.*?</table>)', html, flags=re.DOTALL)
if m:
    html = html[:m.end()] + iframe_block + html[m.end():]
    print("  YouTube iframe injected after video table.")
else:
    print("  WARNING: video table anchor not found; iframe not injected.")
open(path, "w").write(html)
PY

echo "HTML written: $HTML"

if [[ -n "$CHROME" ]]; then
  echo "Building PDF..."
  "$CHROME" --headless --disable-gpu --no-sandbox \
    --print-to-pdf="$PDF" --print-to-pdf-no-header --no-pdf-header-footer \
    --run-all-compositor-stages-before-draw --virtual-time-budget=5000 \
    "file://$HTML" 2>/dev/null
  echo "PDF written: $PDF"
else
  echo "Skipping PDF (Chrome not found)."
fi
