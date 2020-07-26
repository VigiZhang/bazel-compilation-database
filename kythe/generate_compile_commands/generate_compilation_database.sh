#!/usr/bin/env bash

# Generates a compile_commands.json file at $(bazel info execution_root) for
# your Clang tooling needs.

set -e

WORKSPACE=$(bazel info workspace 2>/dev/null)
OUTFILE=$WORKSPACE/compile_commands.json
KYTHE_WORKSPACE=$(bazel info bazel-bin 2>/dev/null)/../extra_actions/kythe/generate_compile_commands
BAZEL_ROOT=$(bazel info execution_root 2>/dev/null)

[ -d $KYTHE_WORKSPACE ] && find $KYTHE_WORKSPACE -name '*.compile_command.json' -delete

bazel build \
    --color=yes \
    --experimental_action_listener=//kythe/generate_compile_commands:extract_json \
    --nosandbox_debug \
    --noshow_progress \
    --noshow_loading_progress \
    $(bazel query 'kind(cc_.*, //...) - attr(tags, manual, //...) - //kythe/...' 2>/dev/null) >/dev/null

echo "[" >$OUTFILE
find $KYTHE_WORKSPACE -name '*.compile_command.json' -exec cat {} + >>$OUTFILE
echo -e "\n]" >>$OUTFILE
sed -i "s|@BAZEL_ROOT@|$BAZEL_ROOT|g" $OUTFILE
sed -i "s/}{/},\n{/g" $OUTFILE

# Use `jq` to format the compilation database
if hash jq 2>/dev/null; then
    TMPFILE=$(mktemp)
    jq . $OUTFILE >$TMPFILE && mv $TMPFILE $OUTFILE || rm $TMPFILE
fi
