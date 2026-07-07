# demo-steps.example.sh — a steps file for record-demo.sh.
#
# record-demo.sh SOURCES this file, then runs demo() with pacing + on-screen
# labels. Copy it into your project (e.g. demo/steps.sh) and edit for your demo.
#
# Contract:
#   - Set DEMO_TITLE (the banner shown first).
#   - Define demo() and call  step "<label>" "<command>"  once per on-camera command.
#   - step(), the pauses (PAUSE_BEFORE/PAUSE_AFTER), and colors are provided by
#     the recorder — don't redefine them.
#   - The <command> string is run with `eval`, so pipes/quotes/jq all work. A
#     non-zero exit (e.g. an intentional error demo) is tolerated, not fatal.
#   - You can read env vars to make steps conditional (see INCLUDE_LIVE below),
#     and set your own vars/hosts up top.
#
# Run:  record-demo.sh --steps demo/steps.sh
#       record-demo.sh --steps demo/steps.sh --no-record   # rehearse, no capture

DEMO_TITLE="My Service — quick tour"

# Project vars (override from the environment when you invoke the recorder).
HOST="${HOST:-localhost:8080}"

demo() {
  step "1/3  Health check" \
    "curl -s $HOST/healthz | jq ."

  step "2/3  Create a widget" \
    "curl -s -X POST $HOST/widgets -H 'content-type: application/json' -d '{\"name\":\"demo\"}' | jq ."

  # Conditional step: skip anything that shows real secrets with INCLUDE_LIVE=0.
  if [ "${INCLUDE_LIVE:-1}" = "1" ]; then
    step "3/3  Call the live upstream" \
      "curl -s $HOST/upstream/ping | jq ."
  fi
}
