#!/usr/bin/env bash
# Render PORTFOLIO_KO.md -> pdf/portfolio.pdf via python-markdown + headless Chrome.
# Deliberately no pandoc/LaTeX: this is one small pure-python dep plus a browser that
# is already installed. Fonts are system fonts (Pretendard if present, else Noto Sans
# CJK KR) — no font binary is committed to this repo.
set -euo pipefail
cd "$(dirname "$0")/.."

CHROME=$(command -v google-chrome-stable || command -v google-chrome || command -v chromium || true)
[ -n "$CHROME" ] || { echo "no Chrome/Chromium found — HTML is still written to pdf/portfolio.html"; }

python3 - <<'PY'
import markdown, re, pathlib
src = pathlib.Path("PORTFOLIO_KO.md").read_text()
# strip the YAML front matter into a cover block
meta = {}
if src.startswith("---"):
    fm, src = src.split("---", 2)[1:]
    for line in fm.strip().splitlines():
        if ":" in line:
            k, v = line.split(":", 1)
            meta[k.strip()] = v.strip().strip('"')
body = markdown.markdown(src, extensions=["tables", "attr_list", "sane_lists"])
# page break before each top-level section
body = re.sub(r"<h1", '<h1 class="pb"', body)
body = body.replace('<h1 class="pb"', "<h1", 1)

css = """
@page { size: A4; margin: 18mm 16mm; }
:root { --ink:#111; --muted:#555; --rule:#d8d8d8; --accent:#1a4d7a; }
* { box-sizing: border-box; }
body { font-family: Pretendard, "Noto Sans CJK KR", "Noto Sans KR", "Noto Sans CJK JP",
       system-ui, sans-serif; color: var(--ink); font-size: 10.2pt; line-height: 1.62;
       margin: 0; background: #fff; }
.cover { padding: 60mm 0 0 0; page-break-after: always; }
.cover h1 { font-size: 21pt; line-height: 1.35; margin: 0 0 6mm 0; border: 0; padding: 0; }
.cover .sub { font-size: 11pt; color: var(--muted); margin-bottom: 14mm; }
.cover .who { font-size: 11pt; }
.cover .lede { margin-top: 16mm; padding: 6mm 7mm; border-left: 3px solid var(--accent);
               background: #f6f8fa; font-size: 10.5pt; color: #223; }
h1 { font-size: 15pt; margin: 0 0 4mm 0; padding-bottom: 2mm;
     border-bottom: 2px solid var(--accent); color: var(--accent); }
h1.pb { page-break-before: always; margin-top: 0; }
h2 { font-size: 12pt; margin: 7mm 0 3mm; }
h3 { font-size: 10.8pt; margin: 5mm 0 2mm; color: #333; }
p { margin: 0 0 3.2mm; }
ul, ol { margin: 0 0 3.5mm; padding-left: 6mm; }
li { margin-bottom: 1.4mm; }
table { border-collapse: collapse; width: 100%; margin: 3mm 0 5mm; font-size: 9pt;
        page-break-inside: avoid; }
th, td { border: 1px solid var(--rule); padding: 1.6mm 2.2mm; text-align: left;
         vertical-align: top; }
th { background: #eef2f6; font-weight: 600; }
tr:nth-child(even) td { background: #fbfcfd; }
code, pre { font-family: "DejaVu Sans Mono", ui-monospace, monospace; font-size: 8.6pt; }
pre { background: #f6f8fa; border: 1px solid var(--rule); border-radius: 3px;
      padding: 3mm; overflow-x: auto; page-break-inside: avoid; line-height: 1.45; }
code { background: #f2f4f6; padding: 0.3mm 1mm; border-radius: 2px; }
pre code { background: none; padding: 0; }
blockquote { margin: 3mm 0; padding: 2mm 5mm; border-left: 3px solid var(--accent);
             background: #f6f8fa; color: #223; }
strong { font-weight: 650; }
h1, h2, h3 { page-break-after: avoid; }
"""

cover = f"""<div class="cover">
  <h1>{meta.get('title','')}</h1>
  <div class="sub">{meta.get('subtitle','')}</div>
  <div class="who">{meta.get('author','')}</div>
  <div class="lede">데이터가 어떤 형식으로 저장되고 어떤 경로로 이동하는지가 시스템
  병목을 만든다. 그 병목을 시뮬레이터 계측으로 측정 가능한 양으로 바꾸고, 통제된
  실험으로 검증하고, 가설이 틀렸을 때 그것을 결과로 보고한다.</div>
</div>"""

html = ("<!doctype html><html lang=\"ko\"><head><meta charset=\"utf-8\">"
        f"<title>{meta.get('title','portfolio')}</title><style>{css}</style></head>"
        f"<body>{cover}{body}</body></html>")
pathlib.Path("pdf").mkdir(exist_ok=True)
pathlib.Path("pdf/portfolio.html").write_text(html)
print("wrote pdf/portfolio.html")
PY

if [ -n "$CHROME" ]; then
  "$CHROME" --headless --disable-gpu --no-sandbox --no-pdf-header-footer \
    --print-to-pdf="$PWD/pdf/portfolio.pdf" "file://$PWD/pdf/portfolio.html" 2>/dev/null
  echo "wrote pdf/portfolio.pdf ($(du -h pdf/portfolio.pdf | cut -f1))"
fi
