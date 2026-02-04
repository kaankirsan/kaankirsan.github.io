#!/bin/bash
# ===========================================================================
# optimize-images.sh
# Portfolio Image & Video Optimization Script
#
# PREREQUISITES (install before running):
#   Ubuntu/Debian:  sudo apt install imagemagick ffmpeg
#   macOS:          brew install imagemagick ffmpeg
#
# WHAT THIS SCRIPT DOES:
#   1. Re-compresses all JPEGs to quality 75 (visually lossless for web)
#   2. Re-compresses all PNGs with optimized compression
#   3. Resizes images wider than 1200px (max display width on this site)
#      - Card thumbnails: 800px wide (project-image is 250px tall container)
#      - Gallery images: 1200px wide (gallery-grid max column width)
#      - Hero background: kept at original width for cover behaviour
#   4. Generates WebM versions of all MP4 videos (much smaller, ~40-60% savings)
#   5. Extracts poster frames from each video (frame at 2 seconds)
#   6. Removes temp/compressed duplicates that are no longer needed
#   7. Logs before/after sizes
#
# USAGE:
#   chmod +x optimize-images.sh
#   ./optimize-images.sh
#
# OUTPUT:
#   - Optimized images overwrite originals (back them up first if needed)
#   - WebM videos are created alongside MP4s (HTML updated separately)
#   - Poster images saved as <videoname>-poster.jpg
#   - Size report saved to optimization-report.txt
# ===========================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMG_DIR="$SCRIPT_DIR/images/projects"
HERO_IMG="$SCRIPT_DIR/images/hero-bg.jpg"
LOGO_IMG="$SCRIPT_DIR/images/robot-logo.png"
REPORT="$SCRIPT_DIR/optimization-report.txt"

# Colour output helpers
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ---------------------------------------------------------------------------
# Prerequisite checks
# ---------------------------------------------------------------------------
check_prereqs() {
    local missing=0
    for tool in convert identify ffmpeg ffprobe; do
        if ! command -v "$tool" &>/dev/null; then
            log_error "$tool not found. Install ImageMagick and FFmpeg."
            missing=1
        fi
    done
    if [ "$missing" -eq 1 ]; then
        log_error "Aborting. Install prerequisites first."
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# Size helpers
# ---------------------------------------------------------------------------
human_size() { numfmt --to=iec --suffix=B "$1" 2>/dev/null || echo "${1}B"; }

# ---------------------------------------------------------------------------
# Phase 1: Remove orphan temp/compressed duplicates
# ---------------------------------------------------------------------------
cleanup_orphans() {
    log_info "=== Phase 1: Removing orphan temp/compressed files ==="
    local orphans=(
        "$IMG_DIR/wagon-testing-video-02_temp.mp4"
        "$IMG_DIR/solarbot-video-03_compressed.mp4"
    )
    for f in "${orphans[@]}"; do
        if [ -f "$f" ]; then
            local size
            size=$(stat -f%z "$f" 2>/dev/null || stat -c%s "$f" 2>/dev/null)
            log_info "Removing orphan: $(basename "$f") ($(human_size "$size"))"
            rm -f "$f"
        fi
    done
}

# ---------------------------------------------------------------------------
# Phase 2: Optimize JPEGs
# ---------------------------------------------------------------------------
optimize_jpegs() {
    log_info "=== Phase 2: Optimizing JPEGs ==="
    local total_before=0 total_after=0

    # Card thumbnail images (capped at 800px wide)
    local card_images=(
        solarbot-img-02.jpg container-img-03.jpg testing-01.jpg
        welding-img-02.jpg warehouse-img-02.jpg mobile-target-img-01.jpg
        wagon-testing-img-01.jpg troubleshooting-img-04.jpg
        resistance-img-01.jpg webserver-01.jpg exhibitions-img-01.jpg
        personal-img-05.jpg
    )

    for img in "${card_images[@]}"; do
        local path="$IMG_DIR/$img"
        [ -f "$path" ] || continue
        local before
        before=$(stat -c%s "$path" 2>/dev/null || stat -f%z "$path" 2>/dev/null)
        total_before=$((total_before + before))

        # Resize to max 800px wide, then recompress at Q75
        convert "$path" -resize 800x\> -quality 75 -strip "$path"

        local after
        after=$(stat -c%s "$path" 2>/dev/null || stat -f%z "$path" 2>/dev/null)
        total_after=$((total_after + after))
        log_info "  Card: $img  $(human_size "$before") -> $(human_size "$after")"
    done

    # Gallery images (capped at 1200px wide, Q78 to preserve detail)
    find "$IMG_DIR" -maxdepth 1 -name "*.jpg" -o -name "*.jpeg" | while read path; do
        local fname
        fname=$(basename "$path")
        # Skip already-processed card images
        local is_card=0
        for c in "${card_images[@]}"; do [ "$fname" = "$c" ] && is_card=1; done
        [ "$is_card" -eq 1 ] && continue

        local before
        before=$(stat -c%s "$path" 2>/dev/null || stat -f%z "$path" 2>/dev/null)

        convert "$path" -resize 1200x\> -quality 78 -strip "$path"

        local after
        after=$(stat -c%s "$path" 2>/dev/null || stat -f%z "$path" 2>/dev/null)
        log_info "  Gallery: $fname  $(human_size "$before") -> $(human_size "$after")"
    done

    # Hero background: keep width but recompress at Q80 (it is a background, detail matters less)
    if [ -f "$HERO_IMG" ]; then
        local before
        before=$(stat -c%s "$HERO_IMG" 2>/dev/null || stat -f%z "$HERO_IMG" 2>/dev/null)
        convert "$HERO_IMG" -quality 80 -strip "$HERO_IMG"
        local after
        after=$(stat -c%s "$HERO_IMG" 2>/dev/null || stat -f%z "$HERO_IMG" 2>/dev/null)
        log_info "  Hero bg: hero-bg.jpg  $(human_size "$before") -> $(human_size "$after")"
    fi
}

# ---------------------------------------------------------------------------
# Phase 3: Optimize PNGs (strip metadata, re-compress)
# ---------------------------------------------------------------------------
optimize_pngs() {
    log_info "=== Phase 3: Optimizing PNGs ==="
    find "$IMG_DIR" "$SCRIPT_DIR/images" -maxdepth 1 -name "*.png" | while read path; do
        local before
        before=$(stat -c%s "$path" 2>/dev/null || stat -f%z "$path" 2>/dev/null)

        # PNGs on this site are screenshots (testing-img-*) or UI captures.
        # Resize to max 1200px, strip metadata. PNG quality is lossless so
        # we only resize and strip; pngcrush or optipng would give further
        # gains if available.
        convert "$path" -resize 1200x\> -strip "$path"

        local after
        after=$(stat -c%s "$path" 2>/dev/null || stat -f%z "$path" 2>/dev/null)
        [ "$before" -ne "$after" ] && log_info "  PNG: $(basename "$path")  $(human_size "$before") -> $(human_size "$after")"
    done
}

# ---------------------------------------------------------------------------
# Phase 4: Extract video poster frames
# ---------------------------------------------------------------------------
extract_posters() {
    log_info "=== Phase 4: Extracting video poster frames ==="
    # Only extract for videos actually referenced in HTML
    local referenced_videos=(
        container-video-01 container-video-02
        solarbot-video-01 solarbot-video-02 solarbot-video-03 solarbot-video-04
        welding-video-01 welding-video-02
    )

    for vname in "${referenced_videos[@]}"; do
        local vpath="$IMG_DIR/${vname}.mp4"
        local poster="$IMG_DIR/${vname}-poster.jpg"
        [ -f "$vpath" ] || continue
        [ -f "$poster" ] && continue  # already extracted

        # Extract frame at t=2s, resize to 800x450 (16:9), Q80
        ffmpeg -y -i "$vpath" -ss 00:00:02 -frames:v 1 \
               -vf "scale=800:450:force_original_aspect_ratio=decrease,pad=800:450:(ow-iw)/2:(oh-ih)/2" \
               -quality:v 80 "$poster" 2>/dev/null

        if [ -f "$poster" ]; then
            local size
            size=$(stat -c%s "$poster" 2>/dev/null || stat -f%z "$poster" 2>/dev/null)
            log_info "  Poster: $(basename "$poster") ($(human_size "$size"))"
        fi
    done
}

# ---------------------------------------------------------------------------
# Phase 5: Create WebM versions of referenced videos (VP9 codec)
# ---------------------------------------------------------------------------
create_webm() {
    log_info "=== Phase 5: Creating WebM video versions ==="
    local referenced_videos=(
        container-video-01 container-video-02
        solarbot-video-01 solarbot-video-02 solarbot-video-03 solarbot-video-04
        welding-video-01 welding-video-02
    )

    for vname in "${referenced_videos[@]}"; do
        local mp4path="$IMG_DIR/${vname}.mp4"
        local webmpath="$IMG_DIR/${vname}.webm"
        [ -f "$mp4path" ] || continue
        [ -f "$webmpath" ] && continue  # already converted

        local mp4_size
        mp4_size=$(stat -c%s "$mp4path" 2>/dev/null || stat -f%z "$mp4path" 2>/dev/null)
        log_info "  Converting: $(basename "$mp4path") ($(human_size "$mp4_size"))..."

        # VP9 encoding, CRF 30 (good quality), constrained bitrate for streaming
        ffmpeg -y -i "$mp4path" \
               -c:v libvpx-vp9 -crf 30 -b:v 0 -pix_fmt yuv420p \
               -c:a libopus -b:a 64k \
               "$webmpath" 2>/dev/null

        if [ -f "$webmpath" ]; then
            local webm_size
            webm_size=$(stat -c%s "$webmpath" 2>/dev/null || stat -f%z "$webmpath" 2>/dev/null)
            local savings=$(( (mp4_size - webm_size) * 100 / mp4_size ))
            log_info "  WebM: $(basename "$webmpath") ($(human_size "$webm_size")) -- ${savings}% smaller"
        fi
    done
}

# ---------------------------------------------------------------------------
# Phase 6: Re-compress the large unreferenced-but-on-disk videos
#          These are NOT in any HTML <video> tag but still consume repo space.
#          Re-encode at lower CRF to cut size without removing them.
# ---------------------------------------------------------------------------
recompress_unreferenced_videos() {
    log_info "=== Phase 6: Re-compressing large unreferenced videos ==="
    # Videos on disk but NOT in any current HTML page:
    local unreferenced=(
        other-machines-video-01 other-machines-video-02
        personal-video-01 personal-video-02
        resistance-video-01
        troubleshooting-video-01
        wagon-testing-video-01 wagon-testing-video-02 wagon-testing-video-03
        wagon-testing-video-04 wagon-testing-video-05 wagon-testing-video-06
        wagon-testing-video-07 wagon-testing-video-08 wagon-testing-video-09
        wagon-testing-video-10 wagon-testing-video-11
        warehouse-video-01
    )

    for vname in "${unreferenced[@]}"; do
        local vpath="$IMG_DIR/${vname}.mp4"
        [ -f "$vpath" ] || continue

        local before
        before=$(stat -c%s "$vpath" 2>/dev/null || stat -f%z "$vpath" 2>/dev/null)
        # Only re-encode if > 10MB
        [ "$before" -lt 10485760 ] && continue

        local tmppath="$IMG_DIR/${vname}_reenc.mp4"
        log_info "  Re-encoding: $(basename "$vpath") ($(human_size "$before"))..."

        # H.264 re-encode at CRF 28 (much smaller than typical camera output CRF 18-23)
        ffmpeg -y -i "$vpath" \
               -c:v libx264 -crf 28 -preset medium -pix_fmt yuv420p \
               -c:a aac -b:a 64k \
               "$tmppath" 2>/dev/null

        if [ -f "$tmppath" ]; then
            mv "$tmppath" "$vpath"
            local after
            after=$(stat -c%s "$vpath" 2>/dev/null || stat -f%z "$vpath" 2>/dev/null)
            local savings=$(( (before - after) * 100 / before ))
            log_info "  Re-encoded: $(basename "$vpath") $(human_size "$before") -> $(human_size "$after") (${savings}% saved)"
        fi
    done
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    log_info "============================================="
    log_info "  Portfolio Image & Video Optimization"
    log_info "  Started: $(date)"
    log_info "============================================="

    check_prereqs

    # Capture total sizes before
    local img_before video_before
    img_before=$(find "$SCRIPT_DIR/images" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" \) -exec du -cb {} + | tail -1 | awk '{print $1}')
    video_before=$(find "$SCRIPT_DIR/images" -type f -name "*.mp4" -exec du -cb {} + | tail -1 | awk '{print $1}')

    cleanup_orphans
    optimize_jpegs
    optimize_pngs
    extract_posters
    create_webm
    recompress_unreferenced_videos

    # Capture total sizes after
    local img_after video_after
    img_after=$(find "$SCRIPT_DIR/images" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" \) -exec du -cb {} + | tail -1 | awk '{print $1}')
    video_after=$(find "$SCRIPT_DIR/images" -type f -name "*.mp4" -exec du -cb {} + | tail -1 | awk '{print $1}')

    log_info ""
    log_info "============================================="
    log_info "  SUMMARY"
    log_info "============================================="
    log_info "  Images: $(human_size "$img_before") -> $(human_size "$img_after")"
    log_info "  Videos: $(human_size "$video_before") -> $(human_size "$video_after")"
    log_info "  Completed: $(date)"
    log_info "============================================="
}

main "$@"
