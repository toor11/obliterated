#!/usr/bin/env bash
# ============================================================
# Personal AI Model Archive Downloader + Weekly Updater
# ============================================================
#
# Features:
#   - Interactive checkbox model selection
#   - Real size calculation from Hugging Face before download
#   - Prefills used space at 0
#   - Progress bars
#   - Full resume support (safe to Ctrl+C)
#   - Weekly update mode (--update)
#   - Source choice: Hugging Face or Pirate Face (swarm)
#   - pirateface is OPTIONAL (only installed if user selects it)
#   - MD5 + SHA-256 integrity check after every download
#   - Optimized Hugging Face Hub Transfer
#
# Usage:
#   ./download_archive.sh                  Interactive download
#   ./download_archive.sh --update         Check & download updates
#   ./download_archive.sh --update -y      Non-interactive update (cron)
#   ./download_archive.sh --pirateface     Force Pirate Face source
#   ./download_archive.sh --hf             Force Hugging Face source
#
# ============================================================

set -euo pipefail

ARCHIVE_ROOT="${ARCHIVE_ROOT:-./model-archive}"
HF_TOKEN="${HF_TOKEN:-}"
MAX_WORKERS="${MAX_WORKERS:-24}"
STATE_FILE=".archive_state"
VERSIONS_FILE=".model_versions"
HASHES_DIR=".hashes"
UPDATE_MODE=false
YES_MODE=false
DOWNLOAD_SOURCE="hf"          # hf | pirateface
SOURCE_EXPLICIT=false         # true when --hf / --pirateface was given

# ---------- Parse arguments ----------
for arg in "$@"; do
    case "$arg" in
        --update|-u)           UPDATE_MODE=true ;;
        -y|--yes)              YES_MODE=true ;;
        --hf)                  DOWNLOAD_SOURCE="hf"; SOURCE_EXPLICIT=true ;;
        --pirateface|--pf)     DOWNLOAD_SOURCE="pirateface"; SOURCE_EXPLICIT=true ;;
        -h|--help)
            echo "Usage: $0 [--update] [-y] [--hf|--pirateface]"
            echo
            echo "  (no flags)     Interactive download with model checkboxes"
            echo "  --update       Check for and download model updates"
            echo "  -y             Non-interactive (answer yes to prompts)"
            echo "  --hf           Force Hugging Face as download source"
            echo "  --pirateface   Force Pirate Face swarm as download source"
            exit 0
            ;;
    esac
done

# Resolve the archive root to an absolute path once. The script later `cd`s
# into it; a relative root would make state/hash paths nest inside itself
# (model-archive/model-archive/...) and break resume across runs.
mkdir -p "$ARCHIVE_ROOT"
ARCHIVE_ROOT="$(cd "$ARCHIVE_ROOT" && pwd)"

# ============================================================
# Core dependencies (always required)
# ============================================================
echo "Checking core dependencies..."

command -v hf   >/dev/null || { echo "Error: 'hf' required → pip install -U 'huggingface_hub[hf_transfer]'"; exit 1; }
command -v jq   >/dev/null || { echo "Error: 'jq' required"; exit 1; }
command -v curl >/dev/null || { echo "Error: 'curl' required"; exit 1; }

if ! command -v md5sum >/dev/null && ! command -v md5 >/dev/null; then
    echo "Error: md5sum or md5 required for integrity checks"
    exit 1
fi

# Hugging Face transfer backend (recommended). Only enable it when the package
# is actually importable -- huggingface_hub aborts every download otherwise.
export HF_HUB_DISABLE_PROGRESS_BARS=0
export HF_HUB_DOWNLOAD_TIMEOUT=300
export HF_HUB_ETAG_TIMEOUT=30

if python3 -c "import hf_transfer" 2>/dev/null; then
    export HF_HUB_ENABLE_HF_TRANSFER=1
    echo "✓ hf_transfer backend available"
else
    echo "⚠  hf_transfer not installed – downloads will be slower"
    echo "   Recommended:  pip install -U 'huggingface_hub[hf_transfer]'"
fi

echo

# ---------- Helper: check if pirateface is available ----------
has_pirateface() {
    command -v pf >/dev/null && return 0
    python3 -c "import pirateface" 2>/dev/null && return 0
    return 1
}

# ---------- Helper: install pirateface only when needed ----------
ensure_pirateface() {
    if has_pirateface; then
        echo "✓ pirateface is available"
        return 0
    fi

    echo
    echo "============================================================"
    echo "  pirateface is required for the selected source"
    echo "============================================================"
    echo
    echo "Install it with:"
    echo
    echo "  pip install pirateface"
    echo "  # or"
    echo "  uv pip install pirateface"
    echo

    if $YES_MODE; then
        echo "Non-interactive mode → cannot install automatically."
        echo "Falling back to Hugging Face."
        DOWNLOAD_SOURCE="hf"
        return 1
    fi

    read -p "Install pirateface now? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Skipping Pirate Face. Falling back to Hugging Face."
        DOWNLOAD_SOURCE="hf"
        return 1
    fi

    echo "Installing pirateface..."

    local install_success=false
    local install_output=""
    local install_cmd=""

    # Try uv first if available, then fall back to pip
    if command -v uv >/dev/null; then
        install_cmd="uv pip install pirateface"
        echo "→ Running: $install_cmd"
        if install_output=$(uv pip install pirateface 2>&1); then
            install_success=true
        else
            echo "⚠ uv pip failed:"
            echo "$install_output" | tail -n 15
            echo
            echo "Trying regular pip instead..."
        fi
    fi

    # Fall back to pip (or primary method if uv not present)
    if ! $install_success; then
        install_cmd="pip install pirateface"
        echo "→ Running: $install_cmd"

        if install_output=$(pip install pirateface 2>&1); then
            install_success=true
        else
            echo
            echo "============================================================"
            echo "  ERROR: Failed to install pirateface"
            echo "============================================================"
            echo
            echo "Command that failed: $install_cmd"
            echo
            echo "Last output:"
            echo "$install_output" | tail -n 20
            echo
            echo "Possible causes:"
            echo "  • No internet connection"
            echo "  • pip/uv not working or missing permissions"
            echo "  • Python environment issues (try a virtualenv)"
            echo "  • PyPI temporarily unavailable"
            echo
            echo "You can try manually:"
            echo "  pip install pirateface"
            echo "  # or"
            echo "  uv pip install pirateface"
            echo
            echo "Falling back to Hugging Face downloads."
            DOWNLOAD_SOURCE="hf"
            return 1
        fi
    fi

    # Final verification after successful install command
    if has_pirateface; then
        echo "✓ pirateface installed successfully"
        return 0
    else
        echo
        echo "⚠ Installation command succeeded but pirateface is still not detectable."
        echo "  Possible reasons:"
        echo "  • Installed into a different Python environment"
        echo "  • PATH does not include the Scripts/bin directory"
        echo "  • You may need to restart the shell"
        echo
        echo "Falling back to Hugging Face."
        DOWNLOAD_SOURCE="hf"
        return 1
    fi
}

# ============================================================
# Source selection
# ============================================================
if ! $UPDATE_MODE && ! $SOURCE_EXPLICIT && ! $YES_MODE; then
    echo "============================================================"
    echo "  CHOOSE DOWNLOAD SOURCE"
    echo "============================================================"
    echo
    echo "  1) Hugging Face          (official – always available)"
    echo "  2) Pirate Face (swarm)   (optional – BitTorrent + HF fallback)"
    echo

    if has_pirateface; then
        echo "  ✓ pirateface is already installed"
    else
        echo "  ℹ  pirateface is not installed (will be offered only if you choose option 2)"
    fi
    echo

    read -p "Select source [1/2] (default 1): " src_choice
    case "$src_choice" in
        2) DOWNLOAD_SOURCE="pirateface" ;;
        *) DOWNLOAD_SOURCE="hf" ;;
    esac
fi

# Validate (and, interactively, install) Pirate Face whenever it is the
# selected source -- including --update --pirateface, where no prompt is shown.
# ensure_pirateface falls back to Hugging Face if it cannot be installed.
if [[ "$DOWNLOAD_SOURCE" == "pirateface" ]]; then
    ensure_pirateface || true
fi

echo "Download source : $DOWNLOAD_SOURCE"
echo

# ============================================================
# Model definitions
# ============================================================
declare -A MODEL_REPOS

MODEL_REPOS["Qwen3.8-27B"]=$(cat <<EOF
Qwen/Qwen3.8-27B|Qwen3.8-27B/original|
unsloth/Qwen3.8-27B-GGUF|Qwen3.8-27B/quantizations|*Q4*
unsloth/Qwen3.8-27B-GGUF|Qwen3.8-27B/quantizations|*Q5*
unsloth/Qwen3.8-27B-GGUF|Qwen3.8-27B/quantizations|*Q6*
unsloth/Qwen3.8-27B-GGUF|Qwen3.8-27B/quantizations|*Q8*
OBLITERATUS/Qwen3.8-27B-OBLITERATED|Qwen3.8-27B/variants/OBLITERATUS|
InterpreticAI/Qwen3.8-27B-Uncensored-v3|Qwen3.8-27B/variants/Uncensored-v3|
huihui-ai/Huihui-Qwen3.8-27B-abliterated-GGUF|Qwen3.8-27B/variants/huihui-abliterated-GGUF|
EOF
)

MODEL_REPOS["Qwen3.8-Flash-Next"]=$(cat <<EOF
Qwen/Qwen3.8-Flash-Next|Qwen3.8-Flash-Next/original|
Qwen/Qwen3.8-Flash-Next-FP8|Qwen3.8-Flash-Next/original-fp8|
orcarouter/Qwen3.8-Flash-Next-Uncensored|Qwen3.8-Flash-Next/variants/orcarouter-Uncensored|
orcarouter/Qwen3.8-Flash-Next-Uncensored-GGUF|Qwen3.8-Flash-Next/variants/orcarouter-Uncensored-GGUF|
EOF
)

MODEL_REPOS["GLM-5.3-Flash"]=$(cat <<EOF
zai-org/GLM-5.3-Flash|GLM-5.3-Flash/original|
dealignai/GLM-5.3-Flash-ABLITERATED-FP8|GLM-5.3-Flash/variants/dealignai-ABLITERATED-FP8|
EOF
)

MODEL_REPOS["DeepSeek-V4.1-Flash-1017"]=$(cat <<EOF
deepseek-ai/DeepSeek-V4.1-Flash-1017|DeepSeek-V4.1-Flash-1017/original|
OpenUncensored/DeepSeek-V4.1-Flash-1017-Uncensored|DeepSeek-V4.1-Flash-1017/variants/OpenUncensored|
EOF
)

MODEL_REPOS["Inkling-2-Mini"]=$(cat <<EOF
thinkingmachines/Inkling-2-Mini|Inkling-2-Mini/original|
IndrasMirror/Inkling-2-Mini-XQ-Uncensored|Inkling-2-Mini/variants/IndrasMirror-XQ-Uncensored|
AtomicChat/Inkling-2-Mini-Uncensored-GGUF|Inkling-2-Mini/variants/AtomicChat-Uncensored-GGUF|
EOF
)

MODEL_REPOS["Qwen3.6-35B-A3B-GGUF"]=$(cat <<EOF
Qwen/Qwen3.6-35B-A3B|Qwen3.6-35B-A3B-GGUF/original|
unsloth/Qwen3.6-35B-A3B-GGUF|Qwen3.6-35B-A3B-GGUF/quantizations|*Q4*
unsloth/Qwen3.6-35B-A3B-GGUF|Qwen3.6-35B-A3B-GGUF/quantizations|*Q5*
unsloth/Qwen3.6-35B-A3B-GGUF|Qwen3.6-35B-A3B-GGUF/quantizations|*Q6*
unsloth/Qwen3.6-35B-A3B-GGUF|Qwen3.6-35B-A3B-GGUF/quantizations|*Q8*
bartowski/Qwen_Qwen3.6-35B-A3B-GGUF|Qwen3.6-35B-A3B-GGUF/quantizations/bartowski|*Q4*
bartowski/Qwen_Qwen3.6-35B-A3B-GGUF|Qwen3.6-35B-A3B-GGUF/quantizations/bartowski|*Q5*
bartowski/Qwen_Qwen3.6-35B-A3B-GGUF|Qwen3.6-35B-A3B-GGUF/quantizations/bartowski|*Q6*
bartowski/Qwen_Qwen3.6-35B-A3B-GGUF|Qwen3.6-35B-A3B-GGUF/quantizations/bartowski|*Q8*
EOF
)

MODELS=(
    "Qwen3.8-27B"
    "Qwen3.8-Flash-Next"
    "GLM-5.3-Flash"
    "DeepSeek-V4.1-Flash-1017"
    "Inkling-2-Mini"
    "Qwen3.6-35B-A3B-GGUF"
)

# ============================================================
# Helpers
# ============================================================
load_completed() {
    declare -gA COMPLETED=()
    [[ -f "$ARCHIVE_ROOT/$STATE_FILE" ]] || return
    while IFS= read -r line; do
        [[ -n "$line" ]] && COMPLETED["$line"]=1
    done < "$ARCHIVE_ROOT/$STATE_FILE"
}

mark_completed() {
    local key="$1"
    mkdir -p "$ARCHIVE_ROOT"
    grep -qxF "$key" "$ARCHIVE_ROOT/$STATE_FILE" 2>/dev/null || echo "$key" >> "$ARCHIVE_ROOT/$STATE_FILE"
    COMPLETED["$key"]=1
}

is_completed() {
    [[ -n "${COMPLETED[$1]:-}" ]]
}

get_remote_commit() {
    local repo_id="$1"
    local headers=()
    [[ -n "$HF_TOKEN" ]] && headers+=(-H "Authorization: Bearer $HF_TOKEN")
    curl -s --max-time 15 "${headers[@]}" "https://huggingface.co/api/models/$repo_id" \
        | jq -r '.sha // empty' 2>/dev/null || echo ""
}

load_versions() {
    declare -gA LOCAL_VERSIONS=()
    [[ -f "$ARCHIVE_ROOT/$VERSIONS_FILE" ]] || return
    while IFS='=' read -r repo hash; do
        [[ -n "$repo" && -n "$hash" ]] && LOCAL_VERSIONS["$repo"]="$hash"
    done < "$ARCHIVE_ROOT/$VERSIONS_FILE"
}

save_version() {
    local repo_id="$1"
    local hash="$2"
    mkdir -p "$ARCHIVE_ROOT"
    if [[ -f "$ARCHIVE_ROOT/$VERSIONS_FILE" ]]; then
        grep -v "^${repo_id}=" "$ARCHIVE_ROOT/$VERSIONS_FILE" > "$ARCHIVE_ROOT/$VERSIONS_FILE.tmp" || true
        mv "$ARCHIVE_ROOT/$VERSIONS_FILE.tmp" "$ARCHIVE_ROOT/$VERSIONS_FILE"
    fi
    echo "${repo_id}=${hash}" >> "$ARCHIVE_ROOT/$VERSIONS_FILE"
    LOCAL_VERSIONS["$repo_id"]="$hash"
}

get_repo_size() {
    local repo_id="$1"
    local include_pattern="${2:-}"
    local headers=()
    [[ -n "$HF_TOKEN" ]] && headers+=(-H "Authorization: Bearer $HF_TOKEN")

    local response
    response=$(curl -s --max-time 25 "${headers[@]}" "https://huggingface.co/api/models/${repo_id}" 2>/dev/null) || { echo 0; return; }
    echo "$response" | jq -e '.error' >/dev/null 2>&1 && { echo 0; return; }

    if [[ -n "$include_pattern" ]]; then
        local filter
        filter=$(echo "$include_pattern" | tr -d '*')
        echo "$response" | jq -r --arg f "$filter" \
            '[.siblings[]? | select(.rfilename | contains($f)) | .size // 0] | add // 0' 2>/dev/null || echo 0
    else
        echo "$response" | jq -r '[.siblings[]?.size // 0] | add // 0' 2>/dev/null || echo 0
    fi
}

# ---------- Integrity check (MD5 + SHA-256) ----------
compute_hashes() {
    local target_dir="$1"
    local hash_file="$2"

    mkdir -p "$(dirname "$hash_file")"
    : > "$hash_file"

    echo "  Computing integrity hashes (MD5 + SHA-256)..."

    find "$target_dir" -type f ! -name "*.tmp" ! -name "*.lock" -print0 2>/dev/null | sort -z | while IFS= read -r -d '' f; do
        local rel="${f#$target_dir/}"
        local md5 sha

        if command -v md5sum >/dev/null; then
            md5=$(md5sum "$f" | awk '{print $1}')
        else
            md5=$(md5 -q "$f")
        fi

        if command -v sha256sum >/dev/null; then
            sha=$(sha256sum "$f" | awk '{print $1}')
        elif command -v shasum >/dev/null; then
            sha=$(shasum -a 256 "$f" | awk '{print $1}')
        else
            sha="N/A"
        fi

        echo "MD5    $md5  $rel" >> "$hash_file"
        echo "SHA256 $sha  $rel" >> "$hash_file"
    done

    echo "  ✓ Hashes written to $hash_file"
}

verify_hashes() {
    local target_dir="$1"
    local hash_file="$2"
    [[ -f "$hash_file" ]] || return 1

    echo "  Verifying existing hashes..."
    local failed=0

    while read -r type expected path; do
        [[ -z "$type" ]] && continue
        local full="$target_dir/$path"
        [[ -f "$full" ]] || { echo "  ✗ Missing: $path"; failed=1; continue; }

        local actual
        if [[ "$type" == "MD5" ]]; then
            if command -v md5sum >/dev/null; then
                actual=$(md5sum "$full" | awk '{print $1}')
            else
                actual=$(md5 -q "$full")
            fi
        else
            if command -v sha256sum >/dev/null; then
                actual=$(sha256sum "$full" | awk '{print $1}')
            else
                actual=$(shasum -a 256 "$full" | awk '{print $1}')
            fi
        fi

        if [[ "$actual" != "$expected" ]]; then
            echo "  ✗ $type mismatch: $path"
            failed=1
        fi
    done < <(awk 'NF>=3 {print $1, $2, substr($0, index($0,$3))}' "$hash_file")

    [[ $failed -eq 0 ]] && echo "  ✓ All hashes OK" || echo "  ⚠ Some hashes failed"
    return $failed
}

print_overall_progress() {
    local used=$1
    local total=$2
    local width=40
    local percent=0
    if (( total > 0 )); then
        percent=$(( used * 100 / total ))
    fi
    local filled=$(( percent * width / 100 ))
    local empty=$(( width - filled ))
    local bar=""
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done
    local used_gb total_gb
    used_gb=$(awk "BEGIN {printf \"%.2f\", $used/1073741824}")
    total_gb=$(awk "BEGIN {printf \"%.2f\", $total/1073741824}")
    printf "\rOverall: [%s] %3d%%  (%s / %s GB)" "$bar" "$percent" "$used_gb" "$total_gb"
}

# ---------- Download function ----------
download_repo() {
    local repo_id="$1"
    local target_dir="$2"
    local include_pattern="${3:-}"
    local size_bytes="${4:-0}"
    local key="$5"
    local force="${6:-false}"

    echo
    echo "────────────────────────────────────────────────────────────"
    echo "→ $repo_id"
    echo "  Target : $target_dir"
    echo "  Source : $DOWNLOAD_SOURCE"
    print_overall_progress "$USED_BYTES" "$TOTAL_BYTES"
    echo
    echo "────────────────────────────────────────────────────────────"

    mkdir -p "$target_dir"
    local hash_file="$ARCHIVE_ROOT/$HASHES_DIR/$(echo "$key" | tr '/|' '__').hashes"

    # If already completed and hashes exist, optionally verify. In update mode
    # (force=true) a completed repo still has to be re-fetched: hf download
    # only pulls the files whose etag changed.
    if ! $force && is_completed "$key" && [[ -f "$hash_file" ]]; then
        echo "  Already marked complete – verifying hashes..."
        if verify_hashes "$target_dir" "$hash_file"; then
            return 0
        fi
        echo "  Hashes failed – will re-download"
    fi

    local success=false

    if [[ "$DOWNLOAD_SOURCE" == "pirateface" ]]; then
        if has_pirateface; then
            echo "  Using Pirate Face swarm (pf download)..."
            if pf download "$repo_id" --local-dir "$target_dir" 2>/dev/null; then
                success=true
            else
                echo "  Pirate Face failed or model not in swarm – falling back to Hugging Face"
            fi
        else
            echo "  Pirate Face CLI not available – falling back to Hugging Face"
        fi
    fi

    if ! $success; then
        echo "  Using official Hugging Face..."
        local cmd=(hf download "$repo_id"
            --local-dir "$target_dir"
            --max-workers "$MAX_WORKERS")
        [[ -n "$HF_TOKEN" ]] && cmd+=(--token "$HF_TOKEN")
        [[ -n "$include_pattern" ]] && cmd+=(--include "$include_pattern")

        if "${cmd[@]}"; then
            success=true
        fi
    fi

    if $success; then
        compute_hashes "$target_dir" "$hash_file"
        mark_completed "$key"
        local sha
        sha=$(get_remote_commit "$repo_id")
        [[ -n "$sha" ]] && save_version "$repo_id" "$sha"
        USED_BYTES=$((USED_BYTES + size_bytes))
        print_overall_progress "$USED_BYTES" "$TOTAL_BYTES"
        echo
        echo "  ✓ Completed + integrity hashes saved"
        return 0
    else
        echo
        echo "  ⚠ Download failed or interrupted – run again to resume"
        return 1
    fi
}

# ============================================================
# UPDATE MODE
# ============================================================
if $UPDATE_MODE; then
    echo "============================================================"
    echo "  MODEL ARCHIVE – WEEKLY UPDATE CHECK"
    echo "============================================================"
    echo

    mkdir -p "$ARCHIVE_ROOT"
    load_versions
    load_completed

    UPDATES_FOUND=0
    declare -a TO_UPDATE=()

    for model in "${MODELS[@]}"; do
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            IFS='|' read -r repo_id local_path include_pattern <<< "$line"
            key="$repo_id|$include_pattern|$local_path"

            is_completed "$key" || continue

            remote_sha=$(get_remote_commit "$repo_id")
            local_sha="${LOCAL_VERSIONS[$repo_id]:-}"

            if [[ -z "$remote_sha" ]]; then
                echo "  ? $repo_id  (could not fetch remote SHA)"
                continue
            fi

            if [[ "$remote_sha" == "$local_sha" ]]; then
                echo "  ✓ $repo_id  (up to date)"
            else
                echo "  ↑ $repo_id  (update available)"
                echo "      local : ${local_sha:-none}"
                echo "      remote: $remote_sha"
                TO_UPDATE+=("$line")
                UPDATES_FOUND=$((UPDATES_FOUND + 1))
            fi
        done <<< "${MODEL_REPOS[$model]}"
    done

    echo
    if [[ $UPDATES_FOUND -eq 0 ]]; then
        echo "All tracked models are up to date."
        exit 0
    fi

    echo "Found $UPDATES_FOUND repo(s) with updates."
    echo

    if ! $YES_MODE; then
        read -p "Download updates now? [y/N] " -n 1 -r
        echo
        [[ ! $REPLY =~ ^[Yy]$ ]] && { echo "Update cancelled."; exit 0; }
    fi

    USED_BYTES=0
    TOTAL_BYTES=0
    declare -A REPO_SIZES

    for entry in "${TO_UPDATE[@]}"; do
        IFS='|' read -r repo_id local_path include_pattern <<< "$entry"
        size=$(get_repo_size "$repo_id" "$include_pattern")
        REPO_SIZES["$repo_id|$include_pattern|$local_path"]=$size
        TOTAL_BYTES=$((TOTAL_BYTES + size))
    done

    echo "Estimated download size for updates: $(awk "BEGIN {printf \"%.2f\", $TOTAL_BYTES/1073741824}") GB"
    echo

    cd "$ARCHIVE_ROOT"

    for entry in "${TO_UPDATE[@]}"; do
        IFS='|' read -r repo_id local_path include_pattern <<< "$entry"
        key="$repo_id|$include_pattern|$local_path"
        size=${REPO_SIZES[$key]:-0}
        download_repo "$repo_id" "$local_path" "$include_pattern" "$size" "$key" true || true
    done

    echo
    echo "Update run finished."
    exit 0
fi

# ============================================================
# NORMAL INTERACTIVE MODE
# ============================================================

SELECTED=()

if command -v whiptail >/dev/null; then
    CHOICES=$(whiptail --title "AI Model Archive" --checklist \
        "Select models to download (Space=toggle, Enter=confirm):" 22 80 12 \
        "Qwen3.8-27B"              "Qwen3.8-27B + quants + abliterated" ON \
        "Qwen3.8-Flash-Next"       "Flash-Next + FP8 + uncensored" ON \
        "GLM-5.3-Flash"            "GLM-5.3-Flash + abliterated" ON \
        "DeepSeek-V4.1-Flash-1017" "DeepSeek V4.1 + uncensored" ON \
        "Inkling-2-Mini"           "Inkling-2-Mini + uncensored" ON \
        "Qwen3.6-35B-A3B-GGUF"     "Qwen3.6-35B-A3B GGUF (Unsloth + Bartowski)" ON \
        3>&1 1>&2 2>&3) || { echo "Cancelled."; exit 0; }
    eval "SELECTED=($CHOICES)"
elif command -v dialog >/dev/null; then
    CHOICES=$(dialog --stdout --checklist "Select models to download:" 22 80 12 \
        "Qwen3.8-27B" "Qwen3.8-27B + quants + abliterated" on \
        "Qwen3.8-Flash-Next" "Flash-Next + FP8 + uncensored" on \
        "GLM-5.3-Flash" "GLM-5.3-Flash + abliterated" on \
        "DeepSeek-V4.1-Flash-1017" "DeepSeek V4.1 + uncensored" on \
        "Inkling-2-Mini" "Inkling-2-Mini + uncensored" on \
        "Qwen3.6-35B-A3B-GGUF" "Qwen3.6-35B-A3B GGUF (Unsloth + Bartowski)" on) || { echo "Cancelled."; exit 0; }
    eval "SELECTED=($CHOICES)"
else
    echo "============================================================"
    echo "  SELECT MODELS"
    echo "============================================================"
    for i in "${!MODELS[@]}"; do
        printf "  %d) %s\n" $((i+1)) "${MODELS[$i]}"
    done
    echo
    read -p "Enter numbers (e.g. 1 3 5) or 'all': " input
    if [[ "$input" =~ ^[Aa][Ll][Ll]$ ]]; then
        SELECTED=("${MODELS[@]}")
    else
        for num in $input; do
            idx=$((num-1))
            [[ $idx -ge 0 && $idx -lt ${#MODELS[@]} ]] && SELECTED+=("${MODELS[$idx]}")
        done
    fi
fi

[[ ${#SELECTED[@]} -eq 0 ]] && { echo "No models selected."; exit 0; }

echo
echo "Selected models:"
for m in "${SELECTED[@]}"; do echo "  • $m"; done
echo

declare -a REPOS=()
for model in "${SELECTED[@]}"; do
    while IFS= read -r line; do
        [[ -n "$line" ]] && REPOS+=("$line")
    done <<< "${MODEL_REPOS[$model]}"
done

load_completed
load_versions

echo "============================================================"
echo "  QUERYING REAL SIZES FROM HUGGING FACE..."
echo "============================================================"
echo

TOTAL_BYTES=0
declare -A REPO_SIZES
declare -a PENDING_REPOS=()

printf "%-74s %12s %10s\n" "Repository → Local path" "Size" "Status"
printf "%-74s %12s %10s\n" "--------------------------------------------------------------------------" "------------" "----------"

for entry in "${REPOS[@]}"; do
    IFS='|' read -r repo_id local_path include_pattern <<< "$entry"
    key="$repo_id|$include_pattern|$local_path"
    size_bytes=$(get_repo_size "$repo_id" "$include_pattern")
    REPO_SIZES["$key"]=$size_bytes

    if is_completed "$key"; then
        status="DONE"
    else
        status="PENDING"
        PENDING_REPOS+=("$entry")
        TOTAL_BYTES=$((TOTAL_BYTES + size_bytes))
    fi

    if (( size_bytes >= 1073741824 )); then
        human=$(awk "BEGIN {printf \"%.2f GB\", $size_bytes/1073741824}")
    elif (( size_bytes >= 1048576 )); then
        human=$(awk "BEGIN {printf \"%.1f MB\", $size_bytes/1048576}")
    else
        human="${size_bytes} B"
    fi
    printf "%-74s %12s %10s\n" "$repo_id → $local_path" "$human" "$status"
done

TOTAL_GB=$(awk "BEGIN {printf \"%.2f\", $TOTAL_BYTES/1073741824}")
TOTAL_TB=$(awk "BEGIN {printf \"%.3f\", $TOTAL_BYTES/1099511627776}")

echo
echo "============================================================"
echo "  REQUIRED DISK SPACE (remaining)"
echo "============================================================"
echo "Remaining size     : ${TOTAL_GB} GB  (${TOTAL_TB} TB)"
echo "Current used space : 0 GB            (prefilled – only remaining counted)"
echo "Download source    : $DOWNLOAD_SOURCE"
echo "Script is fully resumable – Ctrl+C is safe."
echo "============================================================"
echo

[[ ${#PENDING_REPOS[@]} -eq 0 ]] && { echo "Nothing left to download."; exit 0; }

if command -v df >/dev/null; then
    FREE_KB=$(df -k --output=avail . 2>/dev/null | tail -1 | tr -d ' ' || echo 0)
    FREE_GB=$(awk "BEGIN {printf \"%.1f\", $FREE_KB/1048576}")
    echo "Free space on disk : ${FREE_GB} GB"
    if command -v bc >/dev/null && (( $(echo "$FREE_GB < $TOTAL_GB" | bc -l) )); then
        echo "⚠  WARNING: Not enough free space for remaining downloads."
    fi
    echo
fi

if ! $YES_MODE; then
    read -p "Proceed with remaining downloads? [y/N] " -n 1 -r
    echo
    [[ ! $REPLY =~ ^[Yy]$ ]] && { echo "Aborted."; exit 0; }
fi

USED_BYTES=0
mkdir -p "$ARCHIVE_ROOT"
cd "$ARCHIVE_ROOT"

for entry in "${PENDING_REPOS[@]}"; do
    IFS='|' read -r repo_id local_path include_pattern <<< "$entry"
    key="$repo_id|$include_pattern|$local_path"
    size=${REPO_SIZES[$key]:-0}

    if ! download_repo "$repo_id" "$local_path" "$include_pattern" "$size" "$key"; then
        echo
        echo "Download interrupted or failed."
        echo "Just run the script again to resume from this point."
        exit 1
    fi
done

# Create docs folders
for model in "${SELECTED[@]}"; do
    mkdir -p "$model/docs"
done

echo
echo
echo "============================================================"
echo "  ALL SELECTED DOWNLOADS FINISHED"
echo "============================================================"
print_overall_progress "$USED_BYTES" "$TOTAL_BYTES"
echo
echo
echo "Tracked this session : $(awk "BEGIN {printf \"%.2f\", $USED_BYTES/1073741824}") GB"
echo "Actual disk usage    :"
du -sh . 2>/dev/null || true
echo
echo "State file           : $ARCHIVE_ROOT/$STATE_FILE"
echo "Hashes directory     : $ARCHIVE_ROOT/$HASHES_DIR/"
echo "Archive location     : $(pwd)"
echo
echo "You can re-run the script any time – completed repos will be skipped."
echo "Weekly updates:  ./download_archive.sh --update -y"
