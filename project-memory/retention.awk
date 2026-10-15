FNR == 1 { kind=(FILENAME == active_file ? "active" : "archive"); fence=""; entry=0; metadata=0 }
{
  line=$0
  outside=content(line)
  if (outside && line ~ /^##[ \t]+/) {
    if (line !~ /^## T[0-9]+([ \t]|$)/) error("malformed task heading in " FILENAME ": " line)
    entry=++counts[kind]; metadata=1
    id=line; sub(/^## T/, "", id); sub(/[^0-9].*/, "", id)
    heading[kind,entry]=id+0
  }
  if (!entry) { header[kind]=header[kind] line ORS; next }
  blocks[kind,entry]=blocks[kind,entry] line ORS
  if (outside && line ~ /^## T[0-9]+([ \t]|$)/) next
  if (outside && metadata && line ~ /^seq:[ \t]*/) {
    if (has_seq[kind,entry]++) error("duplicate seq field in " FILENAME)
    value=line; sub(/^seq:[ \t]*/, "", value); value=scalar(value)
    if (value !~ /^[0-9]+$/) error("invalid seq in " FILENAME ": " value)
    sequences[kind,entry]=value+0
  } else if (!outside || trim(line) == "" || line !~ /^[A-Za-z_-]+:/) metadata=0
}
END {
  if (failed) exit 1
  for (k=1;k<=2;k++) {
    kind=(k==1 ? "active" : "archive")
    previous=-1
    for (i=1;i<=counts[kind];i++) {
      if (!has_seq[kind,i]) error("missing seq for T" heading[kind,i] " in " kind " log")
      seq=sequences[kind,i]
      if (seq != heading[kind,i]) error("heading/seq mismatch for T" heading[kind,i])
      if (seen[kind,seq]++) error("duplicate task seq " seq " in " kind " log")
      if (previous>=0 && seq>=previous) error(kind " task log must be newest-first")
      previous=seq
      canonical=blocks[kind,i]; sub(/\n+$/, "", canonical)
      if (kind == "active") active_blocks[seq]=canonical
      else {
        if ((seq in active_blocks) && canonical != active_blocks[seq]) error("conflicting active/archive content for seq " seq)
        if (counts["active"] && !(seq in active_blocks) && seq>=sequences["active",counts["active"]]) error("archive contains an interleaved task sequence: " seq)
      }
    }
  }
  printf "%s", header["active"] > active_output
  for (i=1;i<=counts["active"] && i<=limit;i++) printf "%s", blocks["active",i] > active_output
  if (counts["active"]>limit || counts["archive"] || header["archive"] != "") {
    if (header["archive"] != "") printf "%s", header["archive"] > archive_output
    else printf "---\nimportance: 1\nload: on-demand\nsummary: Historical task log\n---\n\n# Task Log Archive\n\n" > archive_output
    for (i=limit+1;i<=counts["active"];i++) printf "%s", blocks["active",i] > archive_output
    for (i=1;i<=counts["archive"];i++) if (!(sequences["archive",i] in active_blocks)) printf "%s", blocks["archive",i] > archive_output
  }
}
