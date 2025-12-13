function sloc () {
	if [ $# -ne 1 ]; then
		echo "Usage: $0 <extension>"
		return 1
	fi

	EXT="${1}"

	all="$(find -not -path '*.git*' -name "*.${EXT}" -exec sh -c 'echo "$(cat "{}" | grep -Iv "^\\s*\$" | wc -l)|{}"' \; | sort -n | column -R1 -t -s'|' -o' | ')"

	echo "${all}"
	echo "${all}" | awk '{print $1}' | xargs | sed -e 's/ /+/g' | bc
}
