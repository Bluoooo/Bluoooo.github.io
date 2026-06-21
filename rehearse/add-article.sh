#!/bin/bash
# ============================================
# add-article.sh — Add a new article to Rehearse
# ============================================
# Usage:
#   ./add-article.sh "Title" "2026-06-21" "Abstract text" content.md
#   ./add-article.sh "Title" "2026-06-21" "Abstract text" content.html
#
# The content file can be .md (Markdown) or .html (raw HTML).
# The script auto-generates a filename from the title's initials + sequential number.
# ============================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ARTICLES_JSON="$SCRIPT_DIR/articles.json"

# --- Validate arguments ---
if [ "$#" -lt 4 ]; then
  echo "❌ Usage: $0 \"Title\" \"YYYY-MM-DD\" \"Abstract\" content-file.md|.html"
  echo ""
  echo "Example:"
  echo "  $0 \"My New Essay\" \"2026-06-21\" \"A short abstract\" essay.md"
  exit 1
fi

TITLE="$1"
DATE="$2"
ABSTRACT="$3"
CONTENT_FILE="$4"

if [ ! -f "$CONTENT_FILE" ]; then
  echo "❌ Content file not found: $CONTENT_FILE"
  exit 1
fi

# --- Generate filename ---
# Get next ID from articles.json
if [ -f "$ARTICLES_JSON" ]; then
  LAST_ID=$(python3 -c "
import json, sys
with open('$ARTICLES_JSON') as f:
    articles = json.load(f)
print(max(a['id'] for a in articles) if articles else 0)
" 2>/dev/null || echo "0")
else
  LAST_ID=0
fi

NEXT_ID=$((LAST_ID + 1))

# Generate pinyin abbreviation from title
# Take first letter of each word, lowercase, max 6 chars
generate_abbreviation() {
  local title="$1"
  # Remove common punctuation, split by spaces, take first char of each word
  local abbr=""
  for word in $title; do
    # Take first character, lowercase it
    local first_char=$(echo "${word:0:1}" | tr '[:upper:]' '[:lower:]')
    # Only add if it's a letter
    if [[ "$first_char" =~ [a-z] ]]; then
      abbr="${abbr}${first_char}"
    fi
  done
  # If abbreviation is empty or too short, use first 4 chars of first word
  if [ ${#abbr} -lt 2 ]; then
    abbr=$(echo "$title" | tr '[:upper:]' '[:lower:]' | tr -dc 'a-z' | head -c 4)
  fi
  # Cap at 6 characters
  echo "${abbr:0:6}"
}

ABBR=$(generate_abbreviation "$TITLE")
PADDED_ID=$(printf "%03d" "$NEXT_ID")
FILENAME="${ABBR}${PADDED_ID}.html"

echo "📝 Creating article: $FILENAME"

# --- Read content file ---
CONTENT=$(cat "$CONTENT_FILE")
EXT="${CONTENT_FILE##*.}"

# --- Convert Markdown to HTML if needed ---
if [ "$EXT" = "md" ] || [ "$EXT" = "markdown" ]; then
  echo "📄 Converting Markdown to HTML..."

  # Check if pandoc is available
  if command -v pandoc &> /dev/null; then
    CONTENT=$(pandoc "$CONTENT_FILE" -f markdown -t html --no-highlight)
  else
    # Simple inline Markdown → HTML conversion (basic subset)
    echo "⚠️  pandoc not found. Using basic Markdown conversion (headings, paragraphs, bold, italic, blockquote, links)."
    CONTENT=$(python3 -c "
import re, sys

with open('$CONTENT_FILE', 'r', encoding='utf-8') as f:
    md = f.read()

html = md

# Headers
html = re.sub(r'^### (.+)$', r'<h3>\1</h3>', html, flags=re.MULTILINE)
html = re.sub(r'^## (.+)$', r'<h2>\1</h2>', html, flags=re.MULTILINE)
html = re.sub(r'^# (.+)$', r'<h1>\1</h1>', html, flags=re.MULTILINE)

# Blockquotes
html = re.sub(r'^> (.+)$', r'<blockquote>\1</blockquote>', html, flags=re.MULTILINE)

# Bold and italic
html = re.sub(r'\*\*(.+?)\*\*', r'<strong>\1</strong>', html)
html = re.sub(r'\*(.+?)\*', r'<em>\1</em>', html)

# Links
html = re.sub(r'\[(.+?)\]\((.+?)\)', r'<a href=\"\2\">\1</a>', html)

# Paragraphs (lines that don't start with < and aren't empty)
lines = html.split('\n')
result = []
for line in lines:
    stripped = line.strip()
    if stripped and not stripped.startswith('<'):
        result.append('<p>' + stripped + '</p>')
    else:
        result.append(line)
html = '\n'.join(result)

# Clean up empty paragraphs
html = re.sub(r'<p>\s*</p>', '', html)

print(html)
" 2>/dev/null)
  fi
fi

# --- Format date for display ---
DISPLAY_DATE=$(python3 -c "
from datetime import datetime
d = datetime.strptime('$DATE', '%Y-%m-%d')
months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec']
print(f'{months[d.month-1]} {d.day}, {d.year}')
" 2>/dev/null || echo "$DATE")

# --- Generate article HTML ---
ARTICLE_HTML="<!DOCTYPE html>
<html lang=\"en\">
  <head>
    <title>${TITLE} - Rehearse</title>
    <meta property=\"og:title\" content=\"${TITLE} - Rehearse\" />
    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\" />
    <meta charset=\"utf-8\" />

    <style data-tag=\"reset-style-sheet\">
      html { line-height: 1.15; } body { margin: 0; } * { box-sizing: border-box; border-width: 0; border-style: solid; -webkit-font-smoothing: antialiased; } p, li, ul, pre, div, h1, h2, h3, h4, h5, h6, figure, blockquote, figcaption { margin: 0; padding: 0; } button { background-color: transparent; } button, input, optgroup, select, textarea { font-family: inherit; font-size: 100%; line-height: 1.15; margin: 0; } button, select { text-transform: none; } button, [type=\"button\"], [type=\"reset\"], [type=\"submit\"] { -webkit-appearance: button; color: inherit; } a { color: inherit; text-decoration: inherit; } pre { white-space: normal; } input { padding: 2px 4px; } img { display: block; } details { display: block; margin: 0; padding: 0; } summary::-webkit-details-marker { display: none; } html { scroll-behavior: smooth; }
    </style>
    <style data-tag=\"default-style-sheet\">
      html { font-family: Inter; font-size: 1rem; }
      body { font-weight: 400; font-style: normal; letter-spacing: 0.02em; line-height: 1.6; color: var(--color-on-surface); background: var(--color-surface); fill: var(--color-on-surface); }
    </style>
    <link rel=\"stylesheet\" href=\"https://unpkg.com/animate.css@4.1.1/animate.css\" />
    <link rel=\"stylesheet\" href=\"https://fonts.googleapis.com/css2?family=Inter:ital,wght@0,100;0,200;0,300;0,400;0,500;0,600;0,700;0,800;0,900;1,100;1,200;1,300;1,400;1,500;1,600;1,700;1,800;1,900&display=swap\" data-tag=\"font\" />
    <link rel=\"stylesheet\" href=\"https://fonts.googleapis.com/css2?family=Fredoka:wght@300;400;500;600;700&display=swap\" data-tag=\"font\" />
    <link rel=\"stylesheet\" href=\"https://fonts.googleapis.com/css2?family=STIX+Two+Text:ital,wght@0,400;0,500;0,600;0,700;1,400;1,500;1,600;1,700&display=swap\" data-tag=\"font\" />
    <link rel=\"stylesheet\" href=\"https://fonts.googleapis.com/css2?family=Noto+Sans:ital,wght@0,100;0,200;0,300;0,400;0,500;0,600;0,700;0,800;0,900;1,100;1,200;1,300;1,400;1,500;1,600;1,700;1,800;1,900&display=swap\" data-tag=\"font\" />
    <link rel=\"icon\" type=\"image/svg+xml\" href=\"data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><defs><linearGradient id='favicon-gradient' x1='0%25' y1='0%25' x2='100%25' y2='100%25'><stop offset='0%25' stop-color='%236bafe6'/><stop offset='100%25' stop-color='%23e78fb0'/></linearGradient></defs><rect width='100' height='100' rx='20' fill='url(%23favicon-gradient)'/><text x='50' y='60' font-size='40' text-anchor='middle' fill='white' font-family='Inter, sans-serif' font-weight='700'>ZZ</text></svg>\">
  </head>
  <body>
    <link rel=\"stylesheet\" href=\"../style.css\" />
    <link rel=\"stylesheet\" href=\"style.css\" />
    <div class=\"rehearse-container\">

      <!-- Navigation -->
      <navigation-wrapper class=\"navigation-wrapper\">
        <div id=\"Navigation\" class=\"navigation-container1\">
          <nav class=\"navigation-container\">
            <div class=\"navigation-content\">
              <a href=\"../index.html\">
                <div class=\"navigation-brand\">
                  <span class=\"section-title\">ZIQIZHAO.COM</span>
                </div>
              </a>
              <div class=\"navigation-desktop-menu\">
                <a href=\"../index.html\">
                  <div class=\"navigation-link\"><span>About Me</span></div>
                </a>
                <a href=\"../academic.html\">
                  <div class=\"navigation-link\"><span>Academic</span></div>
                </a>
                <a href=\"../business.html\">
                  <div class=\"navigation-link\"><span>Business</span></div>
                </a>
                <a href=\"../rehearse/\">
                  <div class=\"navigation-link navigation-link-blog\"><span>Rehearse</span></div>
                </a>
              </div>
              <button id=\"navToggle\" aria-label=\"Toggle Menu\" aria-expanded=\"false\" class=\"navigation-toggle\">
                <svg fill=\"none\" width=\"24\" xmlns=\"http://www.w3.org/2000/svg\" height=\"24\" stroke=\"currentColor\" viewBox=\"0 0 24 24\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\" class=\"navigation-icon-menu\">
                  <path d=\"M4 6h16M4 12h16M4 18h16\"></path>
                </svg>
              </button>
            </div>
          </nav>
          <div id=\"mobileOverlay\" class=\"navigation-mobile-overlay\">
            <div class=\"navigation-overlay-header\">
              <a href=\"../index.html\">
                <div class=\"navigation-brand\">
                  <span class=\"section-title\">ZIQIZHAO.COM</span>
                </div>
              </a>
              <button id=\"navClose\" aria-label=\"Close Menu\" class=\"navigation-close\">
                <svg fill=\"none\" width=\"24\" xmlns=\"http://www.w3.org/2000/svg\" height=\"24\" stroke=\"currentColor\" viewBox=\"0 0 24 24\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\" class=\"navigation-icon-close\">
                  <path d=\"M18 6L6 18M6 6l12 12\"></path>
                </svg>
              </button>
            </div>
            <div class=\"navigation-overlay-links\">
              <a href=\"../index.html\">
                <div class=\"navigation-overlay-link\"><span>About Me</span></div>
              </a>
              <a href=\"../academic.html\">
                <div class=\"navigation-overlay-link\"><span>Academic</span></div>
              </a>
              <a href=\"../business.html\">
                <div class=\"navigation-overlay-link\"><span>Business</span></div>
              </a>
              <a href=\"../rehearse/\">
                <div class=\"navigation-overlay-link\"><span>Rehearse</span></div>
              </a>
            </div>
            <div class=\"navigation-overlay-footer\">
              <p class=\"section-content\">Ziqi \"Stephen\" Zhao</p>
              <div class=\"navigation-social-minimal\">
                <span class=\"section-content\">Personal Portfolio 2026</span>
              </div>
            </div>
          </div>
          <div class=\"navigation-container2\"><div class=\"navigation-container3\"></div></div>
          <div class=\"navigation-container4\"><div class=\"navigation-container5\"></div></div>
        </div>
      </navigation-wrapper>

      <!-- Article Hero -->
      <section class=\"rehearse-article-hero\">
        <div class=\"rehearse-article-hero-content\">
          <h1>${TITLE}</h1>
          <div class=\"rehearse-article-meta\">
            <span>${DISPLAY_DATE}</span>
            <span>&middot;</span>
            <span>Rehearse #$(printf '%02d' $NEXT_ID)</span>
          </div>
        </div>
      </section>

      <!-- Article Body -->
      <div class=\"rehearse-article-body\">
        <a href=\"../rehearse/\" class=\"rehearse-back\">
          <svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\">
            <path d=\"M19 12H5M12 19l-7-7 7-7\"/>
          </svg>
          Back to Rehearse
        </a>

${CONTENT}

        <p style=\"margin-top: 3em; padding-top: 2em; border-top: 1px solid var(--color-border); color: var(--color-on-surface-secondary); font-size: 0.9rem; font-style: italic;\">
          Written by Ziqi Zhao &middot; Originally published ${DISPLAY_DATE}
        </p>
      </div>

      <!-- Footer -->
      <footer class=\"rehearse-footer\">
        <div class=\"footer-content\">
          <div class=\"footer-brand-row\">
            <span class=\"footer-logo-text\">ZIQIZHAO.COM</span>
          </div>
          <a href=\"../index.html\" class=\"btn btn-outline\">Back to Home</a>
        </div>
      </footer>

    </div>

    <script>
      document.addEventListener('DOMContentLoaded', function() {
        var navToggle = document.getElementById(\"navToggle\");
        var navClose = document.getElementById(\"navClose\");
        var mobileOverlay = document.getElementById(\"mobileOverlay\");
        var overlayLinks = document.querySelectorAll(\".navigation-overlay-link\");

        var openMenu = function() {
          mobileOverlay.classList.add(\"is-active\");
          navToggle.setAttribute(\"aria-expanded\", \"true\");
          document.body.style.overflow = \"hidden\";
        };
        var closeMenu = function() {
          mobileOverlay.classList.remove(\"is-active\");
          navToggle.setAttribute(\"aria-expanded\", \"false\");
          document.body.style.overflow = \"\";
        };

        navToggle.addEventListener(\"click\", openMenu);
        navClose.addEventListener(\"click\", closeMenu);
        overlayLinks.forEach(function(link) { link.addEventListener(\"click\", closeMenu); });
        window.addEventListener(\"keydown\", function(e) {
          if (e.key === \"Escape\" && mobileOverlay.classList.contains(\"is-active\")) closeMenu();
        });

        var nav = document.querySelector(\".navigation-container\");
        window.addEventListener(\"scroll\", function() {
          nav.style.boxShadow = window.pageYOffset > 50 ? \"0 4px 20px rgba(0, 0, 0, 0.05)\" : \"none\";
        });
      });
    </script>
  </body>
</html>"

# --- Write article HTML ---
echo "$ARTICLE_HTML" > "$SCRIPT_DIR/$FILENAME"
echo "✅ Created: rehearse/$FILENAME"

# --- Update articles.json ---
python3 -c "
import json

json_path = '$ARTICLES_JSON'
new_entry = {
    'id': $NEXT_ID,
    'filename': '$FILENAME',
    'title': '''$TITLE''',
    'date': '$DATE',
    'abstract': '''$ABSTRACT'''
}

try:
    with open(json_path, 'r', encoding='utf-8') as f:
        articles = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    articles = []

articles.append(new_entry)

with open(json_path, 'w', encoding='utf-8') as f:
    json.dump(articles, f, ensure_ascii=False, indent=2)

print(f'✅ Updated articles.json (total: {len(articles)} articles)')
"

echo ""
echo "🎉 Done! Article added successfully."
echo "   File:     rehearse/$FILENAME"
echo "   Title:    $TITLE"
echo "   Date:     $DATE"
echo "   ID:       #$NEXT_ID"
echo ""
echo "🌐 Open rehearse/index.html to see it in the list."
