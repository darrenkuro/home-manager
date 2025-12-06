function search()
{
  fd "$@" | fzf -0 | tr -d "\n" | xargs -0 open
}
