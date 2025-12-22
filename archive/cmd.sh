function cmd()
{
    local selected=$(
        {
            : # Reformat alias, trailing ' handled separately since can't distinguish ones in the middle
            alias | sed -E "s/^([^=]+)='?(.*)$/\1\t\2/" | sed "s/'$//"
        } | fzf \
        --prompt="Run: " \
        --with-nth=1 \
        --delimiter='\t' \
        --preview='
            echo "{}" | sed "s/^'\''//; s/'\''$//" | cut -f2 | sed -E "s/(.*); :[[:space:]]*(.*)/\2\n\1/"
        ' \
        --height=40% \
        --print-query
    )


    # Convert string to array by splitting on newlines
    local lines=()
    while IFS= read -r line; do
         lines+=("$line")
    done <<< "$selected"

    # 1-index array in zsh (!?)
    if [[ ${#lines[@]} -eq 2 ]]; then
        local cmd_name=$(echo "${lines[2]}" | cut -f1)
        eval "$cmd_name"
    else
        eval "${lines[1]}"
    fi
}
