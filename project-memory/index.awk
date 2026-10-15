function validate(key,value) {
  if (key == "last_task" && value !~ /^[0-9]+$/) error("invalid last_task: " value)
  if (key == "importance" && value !~ /^[1-5]$/) error("importance must be 1-5: " value)
  if (key == "load" && value != "always" && value != "recent" && value != "on-demand") error("invalid load: " value)
}
function field(line,scope,    key,value) {
  key=line; sub(/:.*/, "", key)
  value=line; sub(/^[^:]+:[ \t]*/, "", value); value=scalar(value)
  if (fields[file,scope,key]++) error("duplicate " key " in " file " " scope)
  validate(key,value)
  values[file,scope,key]=value
}
function inherited(scope,key,fallback,    value) {
  if (fields[file,scope,key]) return values[file,scope,key]
  if (fields[file,"page",key]) return values[file,"page",key]
  return fallback
}
function slug(text,    result,i,c) {
  result=""; text=tolower(text)
  gsub(/—|–|“|”|‘|’|，|。|！|？|：|；|（|）|【|】/, "", text)
  for (i=1;i<=length(text);i++) {
    c=substr(text,i,1)
    if (c ~ /[ \t]/) result=result "-"
    else if (c == "_" || c == "-" || c !~ /[[:punct:]]/) result=result c
  }
  return result
}
function cell(text) { gsub(/\|/, "&#124;", text); return text }
function emit(scope,heading,size,    last,imp,policy,age,rec,tier,load,score,summary,link,anchor) {
  last=inherited(scope,"last_task","")
  imp=inherited(scope,"importance",3)
  policy=inherited(scope,"load","recent")
  age=(last == "" ? 0 : current_seq-last); if (age<0) age=0
  rec=0.5^(age/half_life)
  tier=(rec>=0.67 ? "hot" : (rec>=0.20 ? "warm" : "cold"))
  if (file ~ /^archive\/task-log[^\/]*\.md$/) policy="on-demand"
  load=(policy == "recent" ? "recent:" (tier == "cold" ? "on-demand" : "auto") : policy)
  summary=inherited(scope,"summary",heading)
  if (scope == "page") link=cell(file)
  else {
    anchor=slug(heading)
    if (slug_count[file,anchor]++) anchor=anchor "-" (slug_count[file,anchor]-1)
    link="[" ids[file,scope] "](" file "#" anchor ")"
  }
  # The prefix is used only for sorting and is stripped by the shell wrapper.
  printf "%.8f\t| %s | %s | %s | %s | %s | %d | %.2f | %.2f | %s |\n", rec*imp,link,tier,load,(last == "" ? "—" : last),inherited(scope,"date","—"),imp,rec,rec*imp,cell(summary) > rows_output
  index_rows++
  if (load == "always" || load == "recent:auto") default_bytes+=size
}
FNR == 1 {
  if (fm) error("unterminated frontmatter in " file)
  file=FILENAME; prefix=memory_dir "/"; if (index(file,prefix)==1) file=substr(file,length(prefix)+1)
  files[++file_count]=file; fence=""; fm=0; scope=""; metadata=0; task_metadata=0
}
{
  line=$0; bytes[file]+=length(line)+1
  if (FNR == 1 && line == "---") { fm=1; next }
  if (fm) {
    if (line == "---") { fm=0; next }
    if (line ~ /^(last_task|importance|load|date|summary):/) field(line,"page")
    next
  }
  outside=content(line)
  if (!outside) { if (scope != "") entry_bytes[file,scope]+=length(line)+1; metadata=0; task_metadata=0; next }
  if (line ~ /^# / && titles[file] == "") { titles[file]=line; sub(/^# /,"",titles[file]) }
  if (file ~ /(^|\/)task-log[^\/]*\.md$/ && line ~ /^## T[0-9]+([ \t]|$)/) task_metadata=1
  else if (line !~ /^[A-Za-z_-]+:/) task_metadata=0
  if (task_metadata && line ~ /^seq:[ \t]*/) {
    seq_value=line; sub(/^seq:[ \t]*/,"",seq_value); seq_value=scalar(seq_value)
    if (seq_value !~ /^[0-9]+$/) error("invalid task seq in " file)
    if (seq_value+0>current_seq) current_seq=seq_value+0
  }
  if (line ~ /^## D([0-9][A-Za-z0-9_-]*|[-_][A-Za-z0-9_-]+)([ \t]|$)/) {
    scope="entry" ++entries[file]; metadata=1
    heading=line; sub(/^## /,"",heading)
    headings[file,scope]=heading
    id=heading; sub(/[ \t].*/,"",id)
    if (decision_ids[file,id]++) error("duplicate decision ID " id " in " file)
    ids[file,scope]=id
    entry_bytes[file,scope]=length(line)+1
    next
  }
  if (line ~ /^## /) { scope=""; metadata=0 }
  if (scope != "") entry_bytes[file,scope]+=length(line)+1
  if (scope != "" && metadata && line ~ /^(last_task|importance|load|date|summary):/) field(line,scope)
  else metadata=0
}
END {
  if (failed) exit 1
  if (fm) error("unterminated frontmatter in " file)
  for (f=1;f<=file_count;f++) {
    file=files[f]
    if (entries[file]) {
      for (e=1;e<=entries[file];e++) { scope="entry" e; emit(scope,headings[file,scope],entry_bytes[file,scope]) }
    } else emit("page",titles[file],bytes[file])
  }
  printf "%d\n%d\n%d\n", current_seq,index_rows,default_bytes > stats_output
}
