# Source all functions in /function dir
# Each script will handle whether to be included in its particular env

for f in $HM/functions/*.sh; do
  [ -r "$f" ] && source "$f"
done
