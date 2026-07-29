#!/bin/bash
set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_TMP="$(mktemp -d)"
trap 'rm -rf "$TEST_TMP"' EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

make_fake_codex() {
    local bin_dir="$1"
    mkdir -p "$bin_dir"
    cat > "$bin_dir/codex" <<'FAKE'
#!/bin/bash
set -euo pipefail
prompt="$(cat)"
out=""
schema=""
previous=""
for arg in "$@"; do
    if [ "$previous" = "-o" ]; then out="$arg"; fi
    if [ "$previous" = "--output-schema" ]; then schema="$arg"; fi
    previous="$arg"
done
printf '%s\n' "$(basename "${schema:-implementation}")" >> "$FAKE_PROJECT_DIR/.looper/test/stories/calls.log"

story_id="TST-001"
contract="$FAKE_PROJECT_DIR/.looper/test/stories/$story_id.contract.json"

case "$(basename "${schema:-implementation}")" in
  codex-decomposition-schema.json)
    source_hash="$(printf '%s\n' "$prompt" | sed -n 's/^- Source hash: //p' | head -1)"
    source_kind="$(printf '%s\n' "$prompt" | sed -n 's/^- Source kind: //p' | head -1)"
    disposition="PROPOSED"
    if [ "${FAKE_DECOMPOSITION_NEEDS_HUMAN:-0}" = "1" ]; then disposition="NEEDS_HUMAN"; fi
    inventory_kind="requirement"
    [ "${FAKE_INVALID_DECOMPOSITION:-0}" = "1" ] && inventory_kind="invalid"
    proof_command="test -f app.txt"
    [ "${FAKE_OPTIONAL_PROOF:-0}" = "1" ] && proof_command=""
    jq -n --arg kind "$source_kind" --arg hash "$source_hash" --arg disposition "$disposition" --arg inventoryKind "$inventory_kind" --arg proofCommand "$proof_command" '
      {sourceKind:$kind,sourceHash:$hash,disposition:$disposition,project:"Fixture",description:"Create fixture output",
       sourceInventory:[{id:"REQ-001",kind:$inventoryKind,text:"Create app.txt",location:"Requirement 1"}],
       coverage:(if $disposition=="PROPOSED" then [{sourceId:"REQ-001",storyIds:["TST-001"],acceptanceCriteriaIds:["TST-001-AC-001"]}] else [] end),
       stories:(if $disposition=="PROPOSED" then [{id:"TST-001",title:"Create fixture output",description:"Create the requested fixture output.",
         sourceRefs:["REQ-001"],scope:["Create app.txt"],nonGoals:["No unrelated files"],
         acceptanceCriteria:[{id:"TST-001-AC-001",text:"app.txt exists."}],
         proofExpectations:[({id:"TST-001-PROOF-001",text:"The harness verifies app.txt."} + (if $proofCommand=="" then {} else {command:$proofCommand} end))],
         disappointmentCheck:"The file contains an implementation marker.",dependsOn:[],replaces:[],priority:1}] else [] end),
       unresolvedQuestions:(if $disposition=="NEEDS_HUMAN" then ["Choose the contradictory behavior."] else [] end),
       terminalReason:(if $disposition=="NEEDS_HUMAN" then "The source contains a material contradiction." else "" end)}' > "$out"
    ;;
  codex-decomposition-review-schema.json)
    source_hash="$(printf '%s\n' "$prompt" | sed -n 's/^- Source hash: //p' | head -1)"
    proposal_hash="$(printf '%s\n' "$prompt" | sed -n 's/^- Proposal hash: //p' | head -1)"
    if [ "${FAKE_REVIEW_NEEDS_HUMAN:-0}" = "1" ]; then
      jq -n --arg sh "$source_hash" --arg ph "$proposal_hash" '{sourceHash:$sh,proposalHash:$ph,verdict:"NEEDS_HUMAN",summary:"Material choice required",findings:[],sourceCoverage:[{sourceId:"REQ-001",status:"fail",details:"Ambiguous"}],storyEvaluation:[{storyId:"TST-001",status:"fail",details:"Blocked"}],terminalReason:"Choose the required behavior."}' > "$out"
    elif [ "${FAKE_REVIEW_ALWAYS_CHANGES:-0}" = "1" ] || { [ -n "${FAKE_DECOMPOSITION_CHANGES_ONCE_FILE:-}" ] && [ -f "$FAKE_DECOMPOSITION_CHANGES_ONCE_FILE" ]; }; then
      [ -z "${FAKE_DECOMPOSITION_CHANGES_ONCE_FILE:-}" ] || rm -f "$FAKE_DECOMPOSITION_CHANGES_ONCE_FILE"
      jq -n --arg sh "$source_hash" --arg ph "$proposal_hash" '{sourceHash:$sh,proposalHash:$ph,verdict:"CHANGES_REQUESTED",summary:"Revise the boundaries",findings:[{id:"D-1",priority:"P1",details:"Clarify scope",evidence:"Requirement 1"}],sourceCoverage:[{sourceId:"REQ-001",status:"pass",details:"Covered"}],storyEvaluation:[{storyId:"TST-001",status:"fail",details:"Boundary needs revision"}],terminalReason:""}' > "$out"
    else
      jq -n --arg sh "$source_hash" --arg ph "$proposal_hash" '{sourceHash:$sh,proposalHash:$ph,verdict:"APPROVED",summary:"Complete and bounded",findings:[],sourceCoverage:[{sourceId:"REQ-001",status:"pass",details:"Covered"}],storyEvaluation:[{storyId:"TST-001",status:"pass",details:"Independent and provable"}],terminalReason:""}' > "$out"
    fi
    ;;
  codex-plan-schema.json)
    if [ "${FAKE_PLAN_SIDE_EFFECT:-0}" = "1" ]; then
        echo "planner mutation" > "$FAKE_PROJECT_DIR/planner-side-effect.txt"
    fi
    contract_hash="$(printf '%s\n' "$prompt" | sed -n 's/^- Contract hash: //p' | head -1)"
    disposition="${FAKE_PLAN_DISPOSITION:-PLAN_READY}"
    proof="Harness command and code review"
    [ "${FAKE_MISSING_PROOF:-0}" = "1" ] && proof=""
    jq -n --arg id "$story_id" --arg hash "$contract_hash" --arg disposition "$disposition" --arg proof "$proof" --argjson ac "$(jq '[.acceptanceCriteria[].id]' "$contract")" '
      {storyId:$id,contractHash:$hash,disposition:$disposition,summary:"Grounded fixture plan",
       assumptions:[],evidence:[{path:"README.md",detail:"Fixture ownership evidence"}],
       acProof:($ac|map({acId:.,proof:$proof})),
       steps:(if $disposition=="PLAN_READY" then [{id:"S01",title:"Implement fixture",description:"Create the promised behavior",files:["app.txt"],checks:["test -f app.txt"]}] else [] end),
       risks:[],terminalReason:(if $disposition=="PLAN_READY" then "" else "The fixture requires approved replacement stories" end),replacementStories:[]}' > "$out"
    ;;
  codex-plan-review-schema.json)
    if [ -n "${FAKE_CRASH_ONCE_FILE:-}" ] && [ -f "$FAKE_CRASH_ONCE_FILE" ]; then
        rm "$FAKE_CRASH_ONCE_FILE"
        exit 42
    fi
    contract_hash="$(printf '%s\n' "$prompt" | sed -n 's/^- Contract hash: //p' | head -1)"
    plan_hash="$(printf '%s\n' "$prompt" | sed -n 's/^- Plan hash: //p' | head -1)"
    if [ -n "${FAKE_PLAN_CHANGES_ONCE_FILE:-}" ] && [ -f "$FAKE_PLAN_CHANGES_ONCE_FILE" ]; then
        rm "$FAKE_PLAN_CHANGES_ONCE_FILE"
        jq -n --arg id "$story_id" --arg ch "$contract_hash" --arg ph "$plan_hash" --argjson ac "$(jq '[.acceptanceCriteria[].id]' "$contract")" '
          {storyId:$id,contractHash:$ch,planHash:$ph,verdict:"CHANGES_REQUESTED",summary:"Plan needs stronger evidence",
           findings:[{id:"PLAN-1",priority:"P1",details:"Revise evidence",evidence:"README.md"}],
           acCoverage:($ac|map({acId:.,status:"pass",details:"Mapping is present but plan needs revision"}))}' > "$out"
    else
        jq -n --arg id "$story_id" --arg ch "$contract_hash" --arg ph "$plan_hash" --argjson ac "$(jq '[.acceptanceCriteria[].id]' "$contract")" '
          {storyId:$id,contractHash:$ch,planHash:$ph,verdict:"APPROVED",summary:"Plan covers the locked contract",findings:[],
           acCoverage:($ac|map({acId:.,status:"pass",details:"Mapped to deterministic proof"}))}' > "$out"
    fi
    ;;
  codex-review-schema.json)
    jq -n --argjson ac "$(jq '[.acceptanceCriteria[] | {criterionId:.id,criterion:.text}]' "$contract")" '
      {verdict:"APPROVED",summary:"Implementation matches the approved plan",findings:[],
       acCoverage:($ac|map(. + {status:"pass",details:"Fixture exists and validation passed"})),testGaps:[]}' > "$out"
    ;;
  implementation)
    echo "implemented" > "$FAKE_PROJECT_DIR/app.txt"
    story_file="$FAKE_PROJECT_DIR/.looper/test/stories/$story_id.md"
    STORY_FILE="$story_file" perl -0pi -e '
      my $replacement = qq{<!-- looper:implementation-handoff:start -->\n- Phase: implementation\n\n### Claimed changes\n- Created fixture\n\n### Files changed\n- app.txt\n\n### Checks run\n- harness-owned check\n\n### Remaining risks\n- None\n<!-- looper:implementation-handoff:end -->};
      s/<!-- looper:implementation-handoff:start -->.*?<!-- looper:implementation-handoff:end -->/$replacement/s;
    ' "$story_file"
    ;;
esac
FAKE
    chmod +x "$bin_dir/codex"
}

make_repo() {
    local repo="$1"
    mkdir -p "$repo/.looper/test/stories"
    git -C "$repo" init -q
    git -C "$repo" checkout -q -b looper/test
    git -C "$repo" config user.email test@example.com
    git -C "$repo" config user.name "Looper Test"
    cat > "$repo/README.md" <<'EOF'
# Fixture
EOF
    git -C "$repo" add README.md
    git -C "$repo" commit -qm init
    cat > "$repo/.looper/test/source.md" <<'EOF'
# Fixture source

REQ-001: Create app.txt.
EOF
    local source_hash proposal_hash review_hash
    source_hash="$(sha256sum "$repo/.looper/test/source.md" | awk '{print $1}')"
    mkdir -p "$repo/.looper/test/decomposition"
    cat > "$repo/.looper/test/decomposition/proposal-1.json" <<JSON
{"sourceKind":"spec","sourceHash":"$source_hash","disposition":"PROPOSED","project":"Fixture","description":"Integration fixture","sourceInventory":[{"id":"FR-1","kind":"requirement","text":"Create app.txt","location":"REQ-001"}],"coverage":[{"sourceId":"FR-1","storyIds":["TST-001"],"acceptanceCriteriaIds":["TST-001-AC-001"]}],"stories":[{"id":"TST-001","title":"Create fixture output","description":"As a tester, I want a fixture file so the workflow is proved.","sourceRefs":["FR-1"],"scope":["Create app.txt"],"nonGoals":["No unrelated files"],"acceptanceCriteria":[{"id":"TST-001-AC-001","text":"app.txt exists."}],"proofExpectations":[{"id":"TST-001-PROOF-001","text":"The harness verifies app.txt.","command":"test -f app.txt"}],"disappointmentCheck":"The file contains an implementation marker.","dependsOn":[],"replaces":[],"priority":1}],"unresolvedQuestions":[],"terminalReason":""}
JSON
    proposal_hash="$(sha256sum "$repo/.looper/test/decomposition/proposal-1.json" | awk '{print $1}')"
    cat > "$repo/.looper/test/decomposition/review-1.json" <<JSON
{"sourceHash":"$source_hash","proposalHash":"$proposal_hash","verdict":"APPROVED","summary":"Approved fixture","findings":[],"sourceCoverage":[{"sourceId":"FR-1","status":"pass","details":"Covered"}],"storyEvaluation":[{"storyId":"TST-001","status":"pass","details":"Valid"}],"terminalReason":""}
JSON
    review_hash="$(sha256sum "$repo/.looper/test/decomposition/review-1.json" | awk '{print $1}')"
    cat > "$repo/.looper/test/stories.json" <<JSON
{
  "schemaVersion": 3,
  "project": "Fixture",
  "branchName": "looper/test",
  "description": "Integration fixture",
  "source": {"kind":"spec","hash":"$source_hash","originalPath":"fixture.md"},
  "sourceInventory": [{"id":"FR-1","kind":"requirement","text":"Create app.txt","location":"REQ-001"}],
  "coverage": [{"sourceId":"FR-1","storyIds":["TST-001"],"acceptanceCriteriaIds":["TST-001-AC-001"]}],
  "decomposition": {"kind":"adversarial_decomposition_review","status":"APPROVED","round":1,"sourceHash":"$source_hash","proposalHash":"$proposal_hash","reviewHash":"$review_hash","author":{"agent":"codex","model":""},"reviewer":{"agent":"codex","model":""},"approvedAt":"2026-01-01T00:00:00Z"},
  "stories": [{
    "id": "TST-001",
    "status": "APPROVED",
    "title": "Create fixture output",
    "description": "As a tester, I want a fixture file so the workflow is proved.",
    "sourceRefs": ["FR-1"],
    "scope": ["Create app.txt"],
    "nonGoals": ["No unrelated files"],
    "acceptanceCriteria": [{"id":"TST-001-AC-001","text":"app.txt exists."}],
    "proofExpectations": [{"id":"TST-001-PROOF-001","text":"The harness verifies app.txt.","command":"test -f app.txt"}],
    "disappointmentCheck": "The file contains an implementation marker.",
    "dependsOn": [],
    "replaces": [],
    "priority": 1,
    "passes": false,
    "notes": "",
    "execution": {"status":"PENDING"}
  }]
}
JSON
    cat > "$repo/.looper/test/decomposition/approved.json" <<JSON
{"kind":"adversarial_decomposition_review","status":"APPROVED","sourceHash":"$source_hash","proposalHash":"$proposal_hash","reviewHash":"$review_hash","round":1,"author":{"agent":"codex","model":""},"reviewer":{"agent":"codex","model":""},"approvedAt":"2026-01-01T00:00:00Z"}
JSON
    cat > "$repo/.looper/test/decomposition/state.json" <<JSON
{"status":"APPROVED","round":1,"sourceKind":"spec","sourceHash":"$source_hash","originalPath":"fixture.md","proposalFile":"$repo/.looper/test/decomposition/proposal-1.json","reviewFile":"$repo/.looper/test/decomposition/review-1.json","proposalHash":"$proposal_hash","reviewHash":"$review_hash","author":{"agent":"codex","model":""},"reviewer":{"agent":"codex","model":""},"terminalReason":"","updatedAt":"2026-01-01T00:00:00Z"}
JSON
}

run_looper() {
    local repo="$1" fake_bin="$2"
    shift 2
    (cd "$repo" && env PATH="$fake_bin:$PATH" FAKE_PROJECT_DIR="$repo" \
      LOOPER_IMPLEMENTATION_AGENT=codex LOOPER_REVIEW_AGENT=codex LOOPER_CODEX_BIN="$fake_bin/codex" \
      LOOPER_HEARTBEAT_INTERVAL=1 "$@" "$SOURCE_DIR/bin/looper" 1)
}

make_source_repo() {
    local repo="$1"
    mkdir -p "$repo/.looper/test/stories"
    git -C "$repo" init -q
    git -C "$repo" checkout -q -b looper/test
    git -C "$repo" config user.email test@example.com
    git -C "$repo" config user.name "Looper Test"
    cat > "$repo/README.md" <<'EOF'
# Fixture
EOF
    cat > "$repo/request.md" <<'EOF'
# Requested outcome

REQ-001: Create app.txt. Do not change unrelated files.
EOF
    git -C "$repo" add README.md request.md
    git -C "$repo" commit -qm init
}

run_source_command() {
    local repo="$1" fake_bin="$2"
    shift 2
    (cd "$repo" && env PATH="$fake_bin:$PATH" FAKE_PROJECT_DIR="$repo" \
      LOOPER_IMPLEMENTATION_AGENT=codex LOOPER_REVIEW_AGENT=codex LOOPER_CODEX_BIN="$fake_bin/codex" \
      LOOPER_HEARTBEAT_INTERVAL=1 "$@")
}

test_prepare_source_kinds() {
    local kind repo bin
    for kind in prd spec; do
        repo="$TEST_TMP/prepare-$kind"; bin="$TEST_TMP/prepare-$kind-bin"
        make_source_repo "$repo"; make_fake_codex "$bin"
        run_source_command "$repo" "$bin" "$SOURCE_DIR/bin/looper" prepare "--$kind" request.md >/dev/null
        [ "$(jq -r '.schemaVersion' "$repo/.looper/test/stories.json")" = 3 ] || fail "$kind prepare did not publish schema v3"
        [ "$(jq -r '.source.kind' "$repo/.looper/test/stories.json")" = "$kind" ] || fail "$kind prepare lost source kind"
        [ "$(jq -r '.decomposition.status' "$repo/.looper/test/stories.json")" = APPROVED ] || fail "$kind prepare lacked approval provenance"
        cmp -s "$repo/request.md" "$repo/.looper/test/source.md" || fail "$kind source snapshot was not byte-identical"
    done
}

test_decomposition_revision() {
    local repo="$TEST_TMP/decomp-revision" bin="$TEST_TMP/decomp-revision-bin" marker="$TEST_TMP/decomp-changes"
    make_source_repo "$repo"; make_fake_codex "$bin"; : > "$marker"
    run_source_command "$repo" "$bin" FAKE_DECOMPOSITION_CHANGES_ONCE_FILE="$marker" "$SOURCE_DIR/bin/looper" prepare --spec request.md >/dev/null
    [ -f "$repo/.looper/test/decomposition/proposal-2.json" ] || fail "decomposition revision did not persist proposal 2"
    [ "$(grep -c '^codex-decomposition-review-schema.json$' "$repo/.looper/test/stories/calls.log")" -eq 2 ] || fail "decomposition revision was not re-reviewed"
}

test_decomposition_needs_human() {
    local repo="$TEST_TMP/decomp-human" bin="$TEST_TMP/decomp-human-bin"
    make_source_repo "$repo"; make_fake_codex "$bin"
    if run_source_command "$repo" "$bin" FAKE_DECOMPOSITION_NEEDS_HUMAN=1 "$SOURCE_DIR/bin/looper" prepare --spec request.md >/dev/null 2>&1; then
        fail "NEEDS_HUMAN decomposition unexpectedly succeeded"
    fi
    [ "$(jq -r '.status' "$repo/.looper/test/decomposition/state.json")" = NEEDS_HUMAN ] || fail "NEEDS_HUMAN state was not persisted"
    [ ! -f "$repo/.looper/test/stories.json" ] || fail "NEEDS_HUMAN published stories"
}

test_reviewer_needs_human_and_review_limit() {
    local repo="$TEST_TMP/reviewer-human" bin="$TEST_TMP/reviewer-human-bin"
    make_source_repo "$repo"; make_fake_codex "$bin"
    if run_source_command "$repo" "$bin" FAKE_REVIEW_NEEDS_HUMAN=1 "$SOURCE_DIR/bin/looper" prepare --spec request.md >/dev/null 2>&1; then fail "reviewer NEEDS_HUMAN unexpectedly succeeded"; fi
    [ "$(jq -r '.status' "$repo/.looper/test/decomposition/state.json")" = NEEDS_HUMAN ] || fail "reviewer NEEDS_HUMAN was not persisted"
    repo="$TEST_TMP/review-limit"; bin="$TEST_TMP/review-limit-bin"
    make_source_repo "$repo"; make_fake_codex "$bin"
    if run_source_command "$repo" "$bin" FAKE_REVIEW_ALWAYS_CHANGES=1 LOOPER_DECOMPOSITION_REVIEW_MAX_ROUNDS=2 "$SOURCE_DIR/bin/looper" prepare --spec request.md >/dev/null 2>&1; then fail "review limit unexpectedly succeeded"; fi
    [ "$(jq -r '.status' "$repo/.looper/test/decomposition/state.json")" = REVIEW_LIMIT ] || fail "review limit was not persisted"
}

test_invalid_proposal_and_optional_proof() {
    local repo="$TEST_TMP/invalid-proposal" bin="$TEST_TMP/invalid-proposal-bin"
    make_source_repo "$repo"; make_fake_codex "$bin"
    if run_source_command "$repo" "$bin" FAKE_INVALID_DECOMPOSITION=1 "$SOURCE_DIR/bin/looper" prepare --spec request.md >/dev/null 2>&1; then fail "invalid proposal unexpectedly succeeded"; fi
    [ ! -f "$repo/.looper/test/stories.json" ] || fail "invalid approved proposal published stories"
    repo="$TEST_TMP/optional-proof"; bin="$TEST_TMP/optional-proof-bin"
    make_source_repo "$repo"; make_fake_codex "$bin"
    run_source_command "$repo" "$bin" FAKE_OPTIONAL_PROOF=1 "$SOURCE_DIR/bin/looper" prepare --spec request.md >/dev/null
    jq -e '.stories[0].proofExpectations[0] | has("command")|not' "$repo/.looper/test/stories.json" >/dev/null || fail "optional proof command was not accepted"
}

test_approval_artifact_integrity() {
    local repo="$TEST_TMP/artifact-integrity" bin="$TEST_TMP/artifact-integrity-bin"
    make_source_repo "$repo"; make_fake_codex "$bin"
    run_source_command "$repo" "$bin" "$SOURCE_DIR/bin/looper" prepare --spec request.md >/dev/null
    printf '\n' >> "$repo/.looper/test/decomposition/proposal-1.json"
    if run_source_command "$repo" "$bin" "$SOURCE_DIR/bin/looper" run 1 >/dev/null 2>&1; then fail "tampered proposal artifact was accepted"; fi
    repo="$TEST_TMP/artifact-missing"; bin="$TEST_TMP/artifact-missing-bin"
    make_source_repo "$repo"; make_fake_codex "$bin"
    run_source_command "$repo" "$bin" "$SOURCE_DIR/bin/looper" prepare --spec request.md >/dev/null
    rm "$repo/.looper/test/decomposition/review-1.json"
    if run_source_command "$repo" "$bin" "$SOURCE_DIR/bin/looper" run 1 >/dev/null 2>&1; then fail "missing review artifact was accepted"; fi
}

test_changed_content_and_same_path() {
    local repo="$TEST_TMP/changed-content" bin="$TEST_TMP/changed-content-bin"
    make_source_repo "$repo"; make_fake_codex "$bin"
    run_source_command "$repo" "$bin" "$SOURCE_DIR/bin/looper" prepare --spec request.md >/dev/null
    printf '\nchanged\n' >> "$repo/request.md"
    if run_source_command "$repo" "$bin" "$SOURCE_DIR/bin/looper" prepare --spec request.md >/dev/null 2>&1; then fail "changed source content was accepted"; fi
    repo="$TEST_TMP/same-path"; bin="$TEST_TMP/same-path-bin"
    make_source_repo "$repo"; make_fake_codex "$bin"
    cp "$repo/request.md" "$repo/.looper/test/source.md"
    run_source_command "$repo" "$bin" "$SOURCE_DIR/bin/looper" prepare --spec .looper/test/source.md >/dev/null
}

test_source_idempotency_and_tamper() {
    local repo="$TEST_TMP/source-integrity" bin="$TEST_TMP/source-integrity-bin" calls
    make_source_repo "$repo"; make_fake_codex "$bin"
    run_source_command "$repo" "$bin" "$SOURCE_DIR/bin/looper" prepare --spec request.md >/dev/null
    calls="$(wc -l < "$repo/.looper/test/stories/calls.log")"
    run_source_command "$repo" "$bin" "$SOURCE_DIR/bin/looper" prepare --spec request.md >/dev/null
    [ "$(wc -l < "$repo/.looper/test/stories/calls.log")" -eq "$calls" ] || fail "same-source prepare reran decomposition"
    if run_source_command "$repo" "$bin" "$SOURCE_DIR/bin/looper" prepare --prd request.md >/dev/null 2>&1; then fail "changed source kind was accepted"; fi
    printf '\ntampered\n' >> "$repo/.looper/test/source.md"
    if run_source_command "$repo" "$bin" "$SOURCE_DIR/bin/looper" run 1 >/dev/null 2>&1; then fail "tampered source was runnable"; fi
}

test_start_converges_on_run_engine() {
    local repo="$TEST_TMP/start" bin="$TEST_TMP/start-bin"
    make_source_repo "$repo"; make_fake_codex "$bin"
    run_source_command "$repo" "$bin" "$SOURCE_DIR/bin/looper" start --spec request.md 1 >/dev/null
    [ "$(jq -r '.stories[0].passes' "$repo/.looper/test/stories.json")" = true ] || fail "start did not enter the story execution engine"
}

test_cli_errors() {
    if "$SOURCE_DIR/bin/looper" prepare --prd >/dev/null 2>&1; then fail "missing source path was accepted"; fi
    if "$SOURCE_DIR/bin/looper" prepare --prd a --spec b >/dev/null 2>&1; then fail "multiple source flags were accepted"; fi
    if "$SOURCE_DIR/bin/looper" run 1 extra >/dev/null 2>&1; then fail "extra run argument was accepted"; fi
}

test_happy_path() {
    local repo="$TEST_TMP/happy" bin="$TEST_TMP/happy-bin"
    make_repo "$repo"
    make_fake_codex "$bin"
    run_looper "$repo" "$bin" >/dev/null
    [ "$(jq -r '.stories[0].passes' "$repo/.looper/test/stories.json")" = true ] || fail "happy path did not pass story"
    [ "$(git -C "$repo" log -1 --pretty=%s)" = "TST-001: Create fixture output" ] || fail "happy path did not create final commit"
    [ -f "$repo/.looper/test/stories/TST-001.approved-plan.json" ] || fail "approved plan was not persisted"
    if git -C "$repo" show --name-only --format= HEAD | grep -q '/decomposition/'; then fail "decomposition runtime artifacts were auto-committed"; fi
}

test_plan_review_crash_resume() {
    local repo="$TEST_TMP/crash" bin="$TEST_TMP/crash-bin" marker="$TEST_TMP/crash-once"
    make_repo "$repo"
    make_fake_codex "$bin"
    : > "$marker"
    if run_looper "$repo" "$bin" FAKE_CRASH_ONCE_FILE="$marker" >/dev/null 2>&1; then
        fail "crashing plan review unexpectedly succeeded"
    fi
    [ "$(jq -r '.status' "$repo/.looper/test/stories/TST-001.planning.json")" = REVIEW_REQUIRED ] || fail "crash did not preserve review-required state"
    run_looper "$repo" "$bin" FAKE_CRASH_ONCE_FILE="$marker" >/dev/null
    [ "$(grep -c '^codex-plan-schema.json$' "$repo/.looper/test/stories/calls.log")" -eq 1 ] || fail "resume reran completed planning work"
}

test_commit_failure_resume() {
    local repo="$TEST_TMP/commit" bin="$TEST_TMP/commit-bin" hook_marker
    make_repo "$repo"
    make_fake_codex "$bin"
    hook_marker="$repo/.git/fail-commit-once"
    : > "$hook_marker"
    cat > "$repo/.git/hooks/pre-commit" <<EOF
#!/bin/bash
if [ -f "$hook_marker" ]; then rm "$hook_marker"; exit 1; fi
EOF
    chmod +x "$repo/.git/hooks/pre-commit"
    if run_looper "$repo" "$bin" >/dev/null 2>&1; then
        fail "commit-hook failure unexpectedly succeeded"
    fi
    [ "$(jq -r '.stories[0].passes' "$repo/.looper/test/stories.json")" = false ] || fail "failed commit marked story passed"
    [ "$(jq -r '.phase' "$repo/.looper/test/active-story.json")" = COMMIT_FAILED ] || fail "failed commit state was not persisted"
    local calls_before
    calls_before="$(wc -l < "$repo/.looper/test/stories/calls.log")"
    run_looper "$repo" "$bin" >/dev/null
    [ "$(wc -l < "$repo/.looper/test/stories/calls.log")" -eq "$calls_before" ] || fail "commit resume reran an agent phase"
    [ "$(jq -r '.stories[0].passes' "$repo/.looper/test/stories.json")" = true ] || fail "commit resume did not pass story"
}

test_planning_side_effect_guard() {
    local repo="$TEST_TMP/side-effect" bin="$TEST_TMP/side-effect-bin"
    make_repo "$repo"
    make_fake_codex "$bin"
    if run_looper "$repo" "$bin" FAKE_PLAN_SIDE_EFFECT=1 >/dev/null 2>&1; then
        fail "mutating planner unexpectedly succeeded"
    fi
    [ -f "$repo/planner-side-effect.txt" ] || fail "side-effect fixture was not created"
    [ "$(jq -r '.stories[0].passes' "$repo/.looper/test/stories.json")" = false ] || fail "side-effect planner advanced story"
}

test_plan_revision_before_implementation() {
    local repo="$TEST_TMP/revision" bin="$TEST_TMP/revision-bin" marker="$TEST_TMP/changes-once"
    make_repo "$repo"
    make_fake_codex "$bin"
    : > "$marker"
    run_looper "$repo" "$bin" FAKE_PLAN_CHANGES_ONCE_FILE="$marker" >/dev/null
    [ "$(grep -c '^codex-plan-schema.json$' "$repo/.looper/test/stories/calls.log")" -eq 2 ] || fail "requested plan change did not create a revised plan"
    [ "$(grep -c '^codex-plan-review-schema.json$' "$repo/.looper/test/stories/calls.log")" -eq 2 ] || fail "revised plan was not independently re-reviewed"
    [ -f "$repo/app.txt" ] || fail "approved revised plan did not reach implementation"
}

test_active_lock_beats_reordered_stories() {
    local repo="$TEST_TMP/lock-order" bin="$TEST_TMP/lock-order-bin" marker="$TEST_TMP/lock-crash" tmp
    make_repo "$repo"
    make_fake_codex "$bin"
    : > "$marker"
    run_looper "$repo" "$bin" FAKE_CRASH_ONCE_FILE="$marker" >/dev/null 2>&1 || true
    [ "$(jq -r '.storyId' "$repo/.looper/test/active-story.json")" = TST-001 ] || fail "initial story was not locked"
    tmp="$repo/.looper/test/stories.next.json"
    jq '.stories[0].priority=99
      | .stories = [(.stories[0] | .id="TST-002" | .title="Higher priority replacement candidate" | .priority=1
          | .acceptanceCriteria=[{"id":"TST-002-AC-001","text":"Candidate exists."}]
          | .proofExpectations=[]), .stories[0]]' "$repo/.looper/test/stories.json" > "$tmp"
    mv "$tmp" "$repo/.looper/test/stories.json"
    run_looper "$repo" "$bin" >/dev/null || true
    [ "$(git -C "$repo" log -1 --pretty=%s)" = "TST-001: Create fixture output" ] || fail "resume switched to reordered live story"
}

test_missing_ac_proof_rejected() {
    local repo="$TEST_TMP/missing-proof" bin="$TEST_TMP/missing-proof-bin"
    make_repo "$repo"
    make_fake_codex "$bin"
    if run_looper "$repo" "$bin" FAKE_MISSING_PROOF=1 >/dev/null 2>&1; then
        fail "plan with empty AC proof unexpectedly succeeded"
    fi
    if grep -q '^implementation$' "$repo/.looper/test/stories/calls.log"; then
        fail "invalid AC mapping reached implementation"
    fi
}

test_terminal_planning_disposition() {
    local disposition="$1" repo="$TEST_TMP/terminal-$1" bin="$TEST_TMP/terminal-$1-bin"
    make_repo "$repo"
    make_fake_codex "$bin"
    if run_looper "$repo" "$bin" FAKE_PLAN_DISPOSITION="$disposition" >/dev/null 2>&1; then
        fail "$disposition unexpectedly returned success"
    fi
    if grep -q '^implementation$' "$repo/.looper/test/stories/calls.log"; then
        fail "$disposition reached the implementation agent"
    fi
    [ "$(jq -r '.status' "$repo/.looper/test/stories/TST-001.planning.json")" = "$disposition" ] || fail "$disposition planning state was not persisted"
    [ "$(jq -r '.stories[0].execution.status' "$repo/.looper/test/stories.json")" = "$disposition" ] || fail "$disposition execution state was not persisted"
    [ -f "$repo/.looper/test/active-story.json" ] || fail "$disposition did not preserve the active lock"
    [ "$(jq -r '.storyId' "$repo/.looper/test/active-story.json")" = TST-001 ] || fail "$disposition active lock identity changed"
}

test_terminal_recovery_story_hashes() {
    local repo="$TEST_TMP/terminal-recovery" bin="$TEST_TMP/terminal-recovery-bin" original current tmp
    make_repo "$repo"; make_fake_codex "$bin"
    run_looper "$repo" "$bin" FAKE_PLAN_DISPOSITION=SPLIT_REQUIRED >/dev/null 2>&1 || true
    original="$(jq -r '.storiesHash' "$repo/.looper/test/active-story.json")"
    tmp="$repo/.looper/test/stories.next.json"
    jq '.stories=[(.stories[0] | .id="TST-002" | .title="Replacement" | .replaces=["TST-001"]
      | .acceptanceCriteria=[{"id":"TST-002-AC-001","text":"Replacement exists."}]
      | .proofExpectations=[] | .passes=false | .execution={status:"PENDING"})]
      | .coverage[0].storyIds=["TST-002"] | .coverage[0].acceptanceCriteriaIds=["TST-002-AC-001"]' "$repo/.looper/test/stories.json" > "$tmp"
    mv "$tmp" "$repo/.looper/test/stories.json"
    current="$(sha256sum "$repo/.looper/test/stories.json" | awk '{print $1}')"
    run_looper "$repo" "$bin" >/dev/null 2>&1 || true
    [ "$(jq -r '.originalStoriesHash' "$repo/.looper/test/stories/TST-001.terminal-resolution.json")" = "$original" ] || fail "terminal resolution lost original stories hash"
    [ "$(jq -r '.currentStoriesHash' "$repo/.looper/test/stories/TST-001.terminal-resolution.json")" = "$current" ] || fail "terminal resolution lost current stories hash"
    [ "$(jq -r '.originalSourceHash' "$repo/.looper/test/stories/TST-001.terminal-resolution.json")" = "$(jq -r '.currentSourceHash' "$repo/.looper/test/stories/TST-001.terminal-resolution.json")" ] || fail "terminal resolution conflated source and stories hashes"
}

test_happy_path
test_plan_review_crash_resume
test_commit_failure_resume
test_planning_side_effect_guard
test_plan_revision_before_implementation
test_active_lock_beats_reordered_stories
test_missing_ac_proof_rejected
test_terminal_planning_disposition SPLIT_REQUIRED
test_terminal_planning_disposition BLOCKED
test_terminal_recovery_story_hashes
test_prepare_source_kinds
test_decomposition_revision
test_decomposition_needs_human
test_reviewer_needs_human_and_review_limit
test_invalid_proposal_and_optional_proof
test_approval_artifact_integrity
test_changed_content_and_same_path
test_source_idempotency_and_tamper
test_start_converges_on_run_engine
test_cli_errors
echo "integration tests passed"
