for f in $HM/functions/*.sh; do
  [ -r "$f" ] && source "$f"
done
