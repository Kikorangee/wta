<#
.SYNOPSIS
  Updates an index.html file to remove Vimeo/video playback and replace each card with a link from a .txt file.

.DESCRIPTION
  - Removes the modal player markup and JavaScript.
  - Replaces "videos" wording with "links".
  - Rewrites each existing <article class="card ..."> block to:
      * remove data-vimeo-id
      * remove is-playable class
      * change status to "Available"
      * replace the action button with an <a> that opens the matching link from LinksPath

  If the LinksPath has more links than there are cards in the HTML, an "Additional Resources" section is appended
  with one card per remaining link, and a sidebar navigation entry is added.

.PARAMETER IndexHtmlPath
  Path to the source HTML file (e.g. ".\index (9).html").

.PARAMETER LinksPath
  Path to a text file containing comma-separated links (e.g. ".\links (1).txt").

.PARAMETER OutputHtmlPath
  Path to write the updated HTML file. If omitted, writes "index_links.html" next to the source.

.EXAMPLE
  .\Update-IndexHtmlFromLinks.ps1 -IndexHtmlPath ".\index (9).html" -LinksPath ".\links (1).txt"

.EXAMPLE
  .\Update-IndexHtmlFromLinks.ps1 -IndexHtmlPath ".\index.html" -LinksPath ".\links.txt" -OutputHtmlPath ".\index.html"
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)]
  [string]$IndexHtmlPath,

  [Parameter(Mandatory=$true)]
  [string]$LinksPath,

  [Parameter()]
  [string]$OutputHtmlPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $IndexHtmlPath)) {
  throw "IndexHtmlPath not found: $IndexHtmlPath"
}
if (-not (Test-Path -LiteralPath $LinksPath)) {
  throw "LinksPath not found: $LinksPath"
}

if ([string]::IsNullOrWhiteSpace($OutputHtmlPath)) {
  $dir  = Split-Path -Parent $IndexHtmlPath
  $OutputHtmlPath = Join-Path $dir 'index_links.html'
}

# --- Read inputs ---
$html = Get-Content -LiteralPath $IndexHtmlPath -Raw -Encoding UTF8
$linksRaw = Get-Content -LiteralPath $LinksPath -Raw -Encoding UTF8

# Split on commas, trim, keep only non-empty
$links = $linksRaw -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }

if ($links.Count -eq 0) {
  throw "No links found in $LinksPath. Expected comma-separated URLs."
}

# --- Page-level replacements (remove Vimeo/video wording) ---
# Title
$html = [regex]::Replace($html, '(?s)<title>.*?</title>', '<title>Training Hub — Links</title>')

# Visible headings/text (best-effort - safe if strings are present)
$html = $html.Replace('Training Hub — Vimeo Library', 'Training Hub — Resource Links')
$html = $html.Replace('Training Hub — Vimeo', 'Training Hub — Links')
$html = $html.Replace('Training hub (Vimeo modal playback). Videos without a Vimeo link show as “Coming soon”.', 'Training hub (resource links). Items open in a new tab.')
$html = $html.Replace('Click a card to play in a modal. If a video is not yet published to Vimeo, it will show as “Coming soon”.', 'Click a card to open the resource in a new tab.')

# Counts like "6 videos" -> "6 links"
$html = [regex]::Replace($html, '(\d+)\s+videos', '$1 links')

# Remove the modal CSS block (everything from "/* Modal */" to </style>)
$html = [regex]::Replace($html, '(?s)/\* Modal \*/.*?(?=\r?\n</style>)', '')

# Remove modal markup + script (greedy match up to the closing </script>)
$html = [regex]::Replace($html, '(?s)\s*<div id="videoModal"[\s\S]*</div>\s*<script>[\s\S]*?</script>\s*', "`r`n")

# --- Card rewrites ---
$cardIndex = 0
$cardPattern = '(?s)<article\s+class="card[^"]*"[^>]*>.*?</article>'

$html = [regex]::Replace($html, $cardPattern, {
  param($m)

  $card = $m.Value
  $link = $null
  if ($script:cardIndex -lt $script:links.Count) {
    $link = $script:links[$script:cardIndex]
  }
  $script:cardIndex++

  # Remove Vimeo id attribute + clickable class
  $card = $card -replace '\sdata-vimeo-id="[^"]*"', ''
  $card = $card -replace 'class="card\s+is-playable"', 'class="card"'

  # Replace wording on the button (if present)
  $card = $card -replace 'Play video', 'Open link'
  $card = $card -replace 'Not available yet', 'Open link'

  # Remove standalone word "video" from titles (if present)
  $card = $card -replace '\b[Vv]ideo\b\s*', ''

  # Build replacement status + actions
  if ($link) {
    $statusHtml = '<p class="status">Available</p>'
    $safeLink = [System.Security.SecurityElement]::Escape($link)
    $actionsHtml = "<p class=""actions""><a class=""action"" href=""$safeLink"" target=""_blank"" rel=""noopener noreferrer"">Open link</a></p>"
  } else {
    $statusHtml = '<p class="status soon">Not available</p>'
    $actionsHtml = '<p class="actions"><span class="action disabled">Not available</span></p>'
  }

  # Replace first status paragraph + first actions paragraph
  $card = ([regex] '(?s)<p class="status[^"]*">.*?</p>').Replace($card, $statusHtml, 1)
  $card = ([regex] '(?s)<p class="actions">.*?</p>').Replace($card, $actionsHtml, 1)

  # Collapse accidental double spaces
  $card = $card -replace '  +', ' '

  return $card
})

# --- Add extra links as a new section (if any) ---
$remainingLinks = @()
if ($cardIndex -lt $links.Count) {
  $remainingLinks = $links[$cardIndex..($links.Count-1)]
}

if ($remainingLinks.Count -gt 0) {
  $cards = New-Object System.Text.StringBuilder
  $n0 = 27  # label starts after the original 26 cards
  for ($i=0; $i -lt $remainingLinks.Count; $i++) {
    $n = $n0 + $i
    $title = ('Resource {0:00}' -f $n)
    $safeLink = [System.Security.SecurityElement]::Escape($remainingLinks[$i])

    [void]$cards.AppendLine(@"
    <article class="card">
      <div class="thumb placeholder">
        <div class="poster">
          <div class="badge">Additional Resources</div>
          <div class="poster-title">$title</div>
          <img class="poster-logo" src="/Webfleet-Training-Academy/directtrack-logo.gif" alt="" aria-hidden="true">
        </div>
      </div>
      <div class="card-body">
        <p class="status">Available</p>
        <h3>$title</h3>
        <p class="desc">Open the resource in a new tab.</p>
        <p class="actions"><a class="action" href="$safeLink" target="_blank" rel="noopener noreferrer">Open link</a></p>
      </div>
    </article>
"@)
  }

  $section = @"
    <section class="section" id="additional-resources">
      <div class="section-head">
        <div>
          <p class="eyebrow">Category</p>
          <h2>Additional Resources</h2>
        </div>
        <p>$($remainingLinks.Count) links</p>
      </div>
      <div class="grid">
$($cards.ToString().TrimEnd())
      </div>
    </section>

"@

  # Insert before closing </main>
  $html = $html -replace '(?s)</main>', ($section + '  </main>')

  # Add sidebar nav entry after Orders & Workflow (best-effort)
  $html = [regex]::Replace(
    $html,
    '(</a><a\s+href="#orders-and-workflow">Orders\s*&amp;\s*Workflow\s*<span>\d+</span></a>)',
    ('$1<a href="#additional-resources">Additional Resources <span>' + $remainingLinks.Count + '</span></a>')
  )
}

# --- Safety check: no "vimeo" or "video" should remain ---
if ($html -match '(?i)\bvimeo\b' -or $html -match '(?i)\bvideo\b') {
  Write-Warning "The output still contains the word 'vimeo' and/or 'video'. You may want to search the output file."
}

# --- Write output ---
Set-Content -LiteralPath $OutputHtmlPath -Value $html -Encoding UTF8
Write-Host "Wrote updated HTML: $OutputHtmlPath"
