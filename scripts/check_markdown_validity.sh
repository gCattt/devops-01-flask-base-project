#!/usr/bin/env bash

set -u # treat unset variables as an error
set -o pipefail # make a pipeline fail if any command in it fails

export LC_ALL=C # ensure consistent locale for string comparisons and sorting

POSTS_DIR="posts/en"
BLOG_IMAGES_DIR="static/assets/blog-images"

# images and author images are optional, but if present, they must exist in the blog images directory
REQUIRED_FIELDS=(
    "title"
    "subtitle"
    "author"
    "date"
    "permalink"
    "tags"
    "shortcontent"
)

EXIT_CODE=0

check_post() {
    local file="$1"
    local file_errors=0

    echo "Checking $file"

    # the file must have Markdown extension.
    if [[ "${file##*.}" != "md" ]]; then
        echo "  ERROR: file must have .md extension"
        file_errors=1
    fi

    # find the metadata separator.
    local separator_line
    separator_line="$(grep -n -m 1 '^---[[:space:]]*$' "$file" | cut -d: -f1 || true)"

    if [[ -z "$separator_line" ]]; then
        echo "  ERROR: missing metadata separator '---'"
        file_errors=1
    else
        # metadata must not be empty and the separator must not be the first line.
        if [[ "$separator_line" -eq 1 ]]; then
            echo "  ERROR: metadata section is missing"
            file_errors=1
        fi
    fi

    # extract only the metadata section.
    local metadata=""
    if [[ -n "$separator_line" ]]; then
        metadata="$(head -n "$((separator_line - 1))" "$file")"
    fi

    # check required metadata fields.
    for field in "${REQUIRED_FIELDS[@]}"; do
        if [[ -z "$metadata" ]] || \
           ! grep -qE "^${field}:[[:space:]]*[^[:space:]].*$" <<< "$metadata"; then
            echo "  ERROR: missing or empty field: $field"
            file_errors=1
        fi
    done

    # check for duplicate metadata fields.
    if [[ -n "$metadata" ]]; then
        for field in \
            "${REQUIRED_FIELDS[@]}" \
            "image" \
            "author_image"
        do
            if [[ "$(grep -cE "^${field}:" <<< "$metadata" || true)" -gt 1 ]]; then
                echo "  ERROR: duplicate field: $field"
                file_errors=1
            fi
        done
    fi

    # extract metadata values.
    local date_value=""
    local permalink_value=""
    local image_value=""
    local author_image_value=""

    if [[ -n "$metadata" ]]; then
        date_value="$(sed -n 's/^date:[[:space:]]*//p' <<< "$metadata" | head -n 1)"
        permalink_value="$(sed -n 's/^permalink:[[:space:]]*//p' <<< "$metadata" | head -n 1)"
        image_value="$(sed -n 's/^image:[[:space:]]*//p' <<< "$metadata" | head -n 1)"
        author_image_value="$(sed -n 's/^author_image:[[:space:]]*//p' <<< "$metadata" | head -n 1)"
    fi

    # validate date.
    if [[ -n "$date_value" ]]; then
        if ! DATE_VALUE="$date_value" python3 - <<'PY'
from datetime import datetime
import os

datetime.strptime(os.environ["DATE_VALUE"], "%B %d, %Y")
PY
        then
            echo "  ERROR: invalid date: '$date_value'"
            echo "         expected format: 'Month Day, Year'"
            file_errors=1
        fi
    fi

    # validate permalink.
    if [[ -n "$permalink_value" ]]; then
        if [[ "$permalink_value" =~ [[:space:]] ]]; then
            echo "  ERROR: permalink must not contain spaces: '$permalink_value'"
            file_errors=1
        fi

        if [[ "$permalink_value" == */* ]]; then
            echo "  ERROR: permalink must not contain '/': '$permalink_value'"
            file_errors=1
        fi

        if [[ "$permalink_value" == "." || "$permalink_value" == ".." ]]; then
            echo "  ERROR: invalid permalink: '$permalink_value'"
            file_errors=1
        fi

        # FlatPages resolves posts using the permalink as filename/path.
        local expected_filename
        expected_filename="${permalink_value}.md"

        if [[ "$(basename "$file")" != "$expected_filename" ]]; then
            echo "  ERROR: filename must match permalink"
            echo "         expected: '$expected_filename'"
            echo "         found:    '$(basename "$file")'"
            file_errors=1
        fi
    fi

    # validate optional image.
    if grep -qE '^image:' <<< "$metadata"; then
        if [[ -z "$image_value" ]]; then
            echo "  ERROR: image is present but empty"
            file_errors=1
        elif [[ "$image_value" == */* ]]; then
            echo "  ERROR: image must be a filename, not a path: '$image_value'"
            file_errors=1
        elif [[ ! -f "$BLOG_IMAGES_DIR/$image_value" ]]; then
            echo "  ERROR: image not found: '$BLOG_IMAGES_DIR/$image_value'"
            file_errors=1
        fi
    fi

    # validate optional author image.
    if grep -qE '^author_image:' <<< "$metadata"; then
        if [[ -z "$author_image_value" ]]; then
            echo "  ERROR: author_image is present but empty"
            file_errors=1
        elif [[ "$author_image_value" == */* ]]; then
            echo "  ERROR: author_image must be a filename, not a path: '$author_image_value'"
            file_errors=1
        elif [[ ! -f "$BLOG_IMAGES_DIR/$author_image_value" ]]; then
            echo "  ERROR: author image not found: '$BLOG_IMAGES_DIR/$author_image_value'"
            file_errors=1
        fi
    fi

    # verify that actual Markdown content exists after the separator.
    if [[ -n "$separator_line" ]]; then
        if ! tail -n +"$((separator_line + 1))" "$file" | grep -q '[^[:space:]]'; then
            echo "  ERROR: Markdown content is missing after '---'"
            file_errors=1
        fi
    fi

    if [[ "$file_errors" -ne 0 ]]; then
        EXIT_CODE=1
    fi

    echo
}

# validate a single file passed as an argument.
if [[ "$#" -gt 0 ]]; then
    for file in "$@"; do
        if [[ ! -f "$file" ]]; then
            echo "ERROR: file not found: $file"
            EXIT_CODE=1
            continue
        fi

        check_post "$file"
    done
else
    # validate all Markdown posts.
    shopt -s nullglob
    files=("$POSTS_DIR"/*.md)

    if [[ "${#files[@]}" -eq 0 ]]; then
        echo "ERROR: no Markdown files found in $POSTS_DIR"
        exit 1
    fi

    for file in "${files[@]}"; do
        check_post "$file"
    done
fi

# check permalink uniqueness across all posts.
declare -A PERMALINKS

shopt -s nullglob
all_posts=("$POSTS_DIR"/*.md)

for file in "${all_posts[@]}"; do
    separator_line="$(grep -n -m 1 '^---[[:space:]]*$' "$file" | cut -d: -f1 || true)"

    [[ -z "$separator_line" ]] && continue

    metadata="$(head -n "$((separator_line - 1))" "$file")"
    permalink_value="$(sed -n 's/^permalink:[[:space:]]*//p' <<< "$metadata" | head -n 1)"

    [[ -z "$permalink_value" ]] && continue

    if [[ -n "${PERMALINKS[$permalink_value]:-}" ]]; then
        echo "ERROR: duplicate permalink '$permalink_value'"
        echo "       files:"
        echo "       - ${PERMALINKS[$permalink_value]}"
        echo "       - $file"
        EXIT_CODE=1
    else
        PERMALINKS["$permalink_value"]="$file"
    fi
done

if [[ "$EXIT_CODE" -eq 0 ]]; then
    echo "Markdown validation passed."
else
    echo "Markdown validation failed."
fi

exit "$EXIT_CODE"
