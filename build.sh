#!/usr/bin/env bash
set -euo pipefail

INPUT="./index.html"
OUTPUT="./feed.xml"

# ---------------- Helpers ----------------

meta() {
  grep -oE "<meta name=\"$1\" content=\"[^\"]*\"" "$INPUT" \
    | sed -E 's/.*content="([^"]*)".*/\1/' \
    | head -n1
}

xml_escape() {
  sed -e 's/&/\&amp;/g' \
      -e 's/</\&lt;/g' \
      -e 's/>/\&gt;/g' \
      -e 's/"/\&quot;/g'
}

cdata() {
  sed 's/]]>/]]]]><![CDATA[>/g' | awk '{print "<![CDATA[ " $0 " ]]>" }'
}

rfc822() {
  if date -u -d "$1" "+%a, %d %b %Y %H:%M:%S GMT" >/dev/null 2>&1; then
    date -u -d "$1" "+%a, %d %b %Y %H:%M:%S GMT"
  elif command -v gdate >/dev/null 2>&1; then
    gdate -u -d "$1" "+%a, %d %b %Y %H:%M:%S GMT"
  else
    python3 -c "import datetime,sys; dt=datetime.datetime.fromisoformat(sys.argv[1].replace('Z','+00:00')); print(dt.strftime('%a, %d %b %Y %H:%M:%S GMT'))" "$1"
  fi
}

guid() {
  printf "%s" "$1" | md5sum | awk '{print $1}'
}

# ---------------- Channel ----------------

TITLE="$(meta rss:title)"
DESC="$(meta rss:description)"
LINK="$(meta rss:link)"
IMAGE="$(meta rss:image)"
LANG="$(meta rss:language)"
FEED="$(meta rss:feed)"
CREATOR="$(meta rss:creator)"

LATEST="$(grep -oE 'data-date="[^"]+"' "$INPUT" | sed 's/.*="//;s/"//' | sort -r | head -n1)"
BUILD_DATE="$(rfc822 "$LATEST")"

# ---------------- RSS ----------------

{
echo '<?xml version="1.0" encoding="UTF-8"?>'
echo '<rss xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:content="http://purl.org/rss/1.0/modules/content/" xmlns:atom="http://www.w3.org/2005/Atom" xmlns:media="http://search.yahoo.com/mrss/" version="2.0">'
echo '<channel>'

printf '<title>%s</title>\n' "$(printf "%s" "$TITLE" | cdata)"
printf '<description>%s</description>\n' "$(printf "%s" "$DESC" | cdata)"
printf '<link>%s</link>\n' "$(printf "%s" "$LINK" | xml_escape)"

echo '<image>'
printf '  <url>%s</url>\n' "$(printf "%s" "$IMAGE" | xml_escape)"
printf '  <title>%s</title>\n' "$(printf "%s" "$TITLE" | xml_escape)"
printf '  <link>%s</link>\n' "$(printf "%s" "$LINK" | xml_escape)"
echo '</image>'

echo '<generator>https://rss.app</generator>'
printf '<lastBuildDate>%s</lastBuildDate>\n' "$BUILD_DATE"
printf '<atom:link href="%s" rel="self" type="application/rss+xml"/>\n' "$(printf "%s" "$FEED" | xml_escape)"
printf '<language>%s</language>\n' "$(printf "%s" "$LANG" | cdata)"

grep -oE '<a class="rss-item"[^>]*>' "$INPUT" | while read -r line; do
  URL="$(echo "$line" | sed -nE 's/.*href="([^"]+)".*/\1/p')"
  TITLE_I="$(echo "$line" | sed -nE 's/.*data-title="([^"]+)".*/\1/p')"
  DATE_I="$(echo "$line" | sed -nE 's/.*data-date="([^"]+)".*/\1/p')"
  IMG_I="$(echo "$line" | sed -nE 's/.*data-image="([^"]+)".*/\1/p')"
  SUM_I="$(echo "$line" | sed -nE 's/.*data-summary="([^"]+)".*/\1/p')"

  DESC_HTML="<div><img src=\"$IMG_I\" style=\"width: 100%;\" /><div>$SUM_I</div></div>"

  echo '<item>'
  printf '  <title>%s</title>\n' "$(printf "%s" "$TITLE_I" | cdata)"
  printf '  <description>%s</description>\n' "$(printf "%s" "$DESC_HTML" | cdata)"
  printf '  <link>%s</link>\n' "$(printf "%s" "$URL" | xml_escape)"
  printf '  <guid isPermaLink="false">%s</guid>\n' "$(guid "$URL")"
  printf '  <dc:creator>%s</dc:creator>\n' "$(printf "%s" "$CREATOR" | cdata)"
  printf '  <pubDate>%s</pubDate>\n' "$(rfc822 "$DATE_I")"
  printf '  <media:content medium="image" url="%s"/>\n' "$(printf "%s" "$IMG_I" | xml_escape)"
  echo '</item>'
done

echo '</channel>'
echo '</rss>'
} > "$OUTPUT"

echo "✓ RSS written to feed.xml"

