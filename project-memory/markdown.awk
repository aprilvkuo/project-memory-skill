# Shared helpers for the deliberately small Markdown metadata format.
function trim(value) { sub(/^[ \t\r]+/, "", value); sub(/[ \t\r]+$/, "", value); return value }
function error(message) { print "Error: " message > "/dev/stderr"; failed=1; exit 1 }
function scalar(value,    quote,i,c,result,tail) {
  value=trim(value)
  quote=substr(value,1,1)
  if (quote == "\042" || quote == "\047") {
    result=""
    for (i=2; i<=length(value); i++) {
      c=substr(value,i,1)
      if (c == quote) {
        if (quote == "\047" && substr(value,i+1,1) == quote) { result=result quote; i++; continue }
        tail=trim(substr(value,i+1))
        if (tail != "" && substr(tail,1,1) != "#") error("unexpected text after quoted metadata")
        return result
      }
      if (c == "\\" && quote == "\042" && i<length(value)) { i++; c=substr(value,i,1) }
      result=result c
    }
    error("unterminated quoted metadata")
  }
  sub(/[ \t]+#.*/, "", value)
  return trim(value)
}
# Return true only for content outside backtick/tilde fenced code blocks.
function content(line,    test,c,n,tail,indent) {
  test=line
  for (indent=0;indent<3 && substr(test,1,1)==" ";indent++) test=substr(test,2)
  c=substr(test,1,1)
  if (c == "`" || c == "~") {
    n=0
    while (substr(test,n+1,1) == c) n++
    tail=trim(substr(test,n+1))
    if (n>=3) {
      if (fence == "") { fence=c; fence_length=n; return 0 }
      if (fence == c && n>=fence_length && tail == "") { fence=""; return 0 }
    }
  }
  return fence == ""
}
