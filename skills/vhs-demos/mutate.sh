# mutate.sh — colorize / redact terminal output for VHS recordings.
#
# VHS records whatever ANSI the shell emits — it has no highlighting of its own.
# So to make the important bytes stand out on camera, source this in a tape's
# hidden setup and pipe a command's output through one of these filters:
#
#   Hide
#   Type ". mutate.sh" Enter                       # defines hi / paint / redact
#   Type "export HL_SENSITIVE='Ada Lovelace|555-0100'" Enter
#   Show
#   Type "curl -s $API/record | jq -r .note | hi" Enter
#
# The `| hi` shows on the command line — that's the honest mechanism. Alias it in
# the hidden block (e.g. `alias j='jq -r .note | hi'`) if you want it off camera.
#
# Env-var vocabulary is shared with demo-media's record-demo.sh, so ONE scenario
# file colours both recorders identically:
#   HL_SENSITIVE   regex ( | = alternation ) of raw PII / secrets  -> red
#   HL_TOKENS      regex of "safe" tokens to mark                   -> green
#                  (default: [BRACKETED_TOKENS] like [NAME_x9f], [DRUG_abc])
# Pipe-delimited literal lists work as-is (they're a valid alternation); note a
# literal "." matches any char — quotemeta the parts first if that bites.
#
# Pure system perl — no install. Emits ANSI; strip with
#   ... | sed $'s/\e\\[[0-9;]*m//g'   if you ever need plain text.

# hi — the demo highlighter: raw PII red, bracketed tokens green.
hi() {
  perl -pe '
    BEGIN {
      $P = $ENV{HL_SENSITIVE} // "";
      $T = $ENV{HL_TOKENS} || "\\[[A-Za-z0-9_]+\\]";
    }
    s/($T)/\e[1;32m$1\e[0m/g if length $T;      # tokens  -> green
    s/($P)/\e[1;31m$1\e[0m/g if length $P;       # raw PII -> red
  '
}

# paint '<regex>' [color] — highlight any regex a colour (default yellow).
#   color: red | green | yellow | blue | magenta | cyan
paint() {
  RE="$1" C="${2:-yellow}" perl -pe '
    BEGIN {
      %c = (red=>31, green=>32, yellow=>33, blue=>34, magenta=>35, cyan=>36);
      $n = $c{$ENV{C}} // 33; $re = $ENV{RE};
    }
    s/($re)/\e[1;${n}m$1\e[0m/g if length $re;
  '
}

# redact '<regex>' — replace matches with block glyphs, on-camera (████████).
# For a screenshot you need UNRECOVERABLE, redact in post with demo-media instead.
redact() {
  RE="$1" perl -pe '
    BEGIN { binmode STDOUT, ":utf8"; $re = $ENV{RE}; }
    s/($re)/"\x{2588}" x length($1)/ge if length $re;
  '
}
