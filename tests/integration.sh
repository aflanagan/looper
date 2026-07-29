#!/bin/bash
set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_TMP="$(mktemp -d)"
if [ "${LOOPER_KEEP_TEST_TMP:-0}" = "1" ]; then
    echo "Keeping integration test workspace: $TEST_TMP" >&2
else
    trap 'rm -rf "$TEST_TMP"' EXIT
fi

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
    decomposition_round="$(printf '%s\n' "$prompt" | sed -n 's/^- Decomposition round: \([0-9][0-9]*\) of.*/\1/p' | head -1)"
    [ -n "$decomposition_round" ] || decomposition_round=1
    is_repair=0
    printf '%s\n' "$prompt" | grep -q 'Author-output repair attempt:' && is_repair=1
    if [ -n "${FAKE_CAPTURE_DECOMPOSITION_PROMPTS_DIR:-}" ]; then
      mkdir -p "$FAKE_CAPTURE_DECOMPOSITION_PROMPTS_DIR"
      call_number="$(grep -Ec '^codex-decomposition(-revision)?-schema.json$' "$FAKE_PROJECT_DIR/.looper/test/stories/calls.log")"
      printf '%s\n' "$prompt" > "$FAKE_CAPTURE_DECOMPOSITION_PROMPTS_DIR/author-$call_number.txt"
    fi
    if [ "${FAKE_ASSERT_TARGETED_CONTEXT:-0}" = "1" ] && [ "$decomposition_round" -gt 1 ]; then
      printf '%s\n' "$prompt" | grep -q '## Last Valid Proposal' || exit 81
      printf '%s\n' "$prompt" | grep -q '## Associated Adversarial Review' || exit 82
      printf '%s\n' "$prompt" | grep -q 'Clarify scope' || exit 83
      printf '%s\n' "$prompt" | grep -q 'Preserve all previously accepted content' || exit 84
    fi
    if [ -n "${FAKE_TIMEOUT_ONCE_FILE:-}" ] && [ -f "$FAKE_TIMEOUT_ONCE_FILE" ] \
      && { [ -z "${FAKE_TIMEOUT_ROUND:-}" ] || [ "$decomposition_round" -eq "$FAKE_TIMEOUT_ROUND" ]; }; then
      rm -f "$FAKE_TIMEOUT_ONCE_FILE"
      sleep "${FAKE_TIMEOUT_SLEEP:-10}"
    fi
    if [ "${FAKE_BROAD_SCAN:-0}" = "1" ]; then
      pwd > "$FAKE_PROJECT_DIR/.looper/test/stories/decomposer-pwd.txt"
      printf '%s\n' "$prompt" | grep -q 'Never traverse parent directories' || exit 91
      printf '%s\n' "$prompt" | grep -q 'find /' || exit 92
      sleep "${FAKE_BROAD_SCAN_SLEEP:-10}"
    fi
    if [ "$is_repair" = "1" ] && [ "${FAKE_REPAIR_SLEEP:-0}" -gt 0 ]; then sleep "$FAKE_REPAIR_SLEEP"; fi
    disposition="PROPOSED"
    if [ "${FAKE_DECOMPOSITION_NEEDS_HUMAN:-0}" = "1" ]; then disposition="NEEDS_HUMAN"; fi
    inventory_kind="requirement"
    [ "${FAKE_INVALID_DECOMPOSITION:-0}" = "1" ] && inventory_kind="invalid"
    defect="${FAKE_DECOMPOSITION_DEFECT:-}"
    if [ -n "${FAKE_DECOMPOSITION_DEFECT_ROUND:-}" ] && [ "$decomposition_round" -ne "$FAKE_DECOMPOSITION_DEFECT_ROUND" ]; then defect=""; fi
    if [ "$is_repair" = "1" ] && [ "${FAKE_DECOMPOSITION_DEFECT_ALWAYS:-0}" != "1" ]; then defect=""; inventory_kind="requirement"; fi
    proof_command="test -f app.txt"
    [ "${FAKE_OPTIONAL_PROOF:-0}" = "1" ] && proof_command=""
    terminal_reason=""
    unresolved='[]'
    if [ "$defect" = "terminal_reason" ]; then terminal_reason="N/A"; fi
    if [ "$defect" = "unresolved_questions" ]; then unresolved='["No human decision is actually required."]'; fi
    scope='["Create app.txt"]'
    if [ "$decomposition_round" -gt 1 ]; then scope='["Create app.txt","Preserve the explicit unrelated-file boundary"]'; fi
    jq -n --arg kind "$source_kind" --arg hash "$source_hash" --arg disposition "$disposition" --arg inventoryKind "$inventory_kind" \
      --arg proofCommand "$proof_command" --arg terminalReason "$terminal_reason" --argjson unresolved "$unresolved" --argjson scope "$scope" '
      {sourceKind:$kind,sourceHash:$hash,disposition:$disposition,project:"Fixture",description:"Create fixture output",
       sourceInventory:[{id:"REQ-001",kind:$inventoryKind,text:"Create app.txt",location:"Requirement 1"}],
       coverage:(if $disposition=="PROPOSED" then [{sourceId:"REQ-001",storyIds:["TST-001"],acceptanceCriteriaIds:["TST-001-AC-001"]}] else [] end),
       stories:(if $disposition=="PROPOSED" then [{id:"TST-001",title:"Create fixture output",description:"Create the requested fixture output.",
         sourceRefs:["REQ-001"],scope:$scope,nonGoals:["No unrelated files"],
         acceptanceCriteria:[{id:"TST-001-AC-001",text:"app.txt exists."}],
         proofExpectations:[({id:"TST-001-PROOF-001",text:"The harness verifies app.txt."} + (if $proofCommand=="" then {} else {command:$proofCommand} end))],
         disappointmentCheck:"The file contains an implementation marker.",dependsOn:[],replaces:[],priority:1}] else [] end),
       unresolvedQuestions:(if $disposition=="NEEDS_HUMAN" then ["Choose the contradictory behavior."] else $unresolved end),
       terminalReason:(if $disposition=="NEEDS_HUMAN" then "The source contains a material contradiction." else $terminalReason end)}' > "$out"
    tmp="${out}.tmp"
    case "$defect" in
      source_refs)
        jq '.stories[0].sourceRefs=[]' "$out" > "$tmp" && mv "$tmp" "$out" ;;
      duplicate_inventory)
        jq '.sourceInventory += [.sourceInventory[0]]' "$out" > "$tmp" && mv "$tmp" "$out" ;;
      duplicate_story)
        jq '.stories += [.stories[0]]' "$out" > "$tmp" && mv "$tmp" "$out" ;;
      duplicate_acceptance)
        jq '.stories[0].acceptanceCriteria += [.stories[0].acceptanceCriteria[0]]' "$out" > "$tmp" && mv "$tmp" "$out" ;;
      missing_coverage)
        jq '.coverage=[]' "$out" > "$tmp" && mv "$tmp" "$out" ;;
      missing_acceptance_mapping)
        jq '.coverage[0].acceptanceCriteriaIds=[]' "$out" > "$tmp" && mv "$tmp" "$out" ;;
      acceptance_ownership)
        jq '.stories += [(.stories[0] | .id="TST-002" | .title="Second fixture" | .acceptanceCriteria=[{"id":"TST-002-AC-001","text":"second exists"}] | .sourceRefs=[])]
          | .coverage[0].acceptanceCriteriaIds=["TST-002-AC-001"]' "$out" > "$tmp" && mv "$tmp" "$out" ;;
      unknown_dependency)
        jq '.stories[0].dependsOn=["TST-404"]' "$out" > "$tmp" && mv "$tmp" "$out" ;;
      forward_dependency)
        jq '.stories = [(.stories[0] | .id="TST-002" | .title="Earlier array entry" | .dependsOn=["TST-001"] | .acceptanceCriteria=[{"id":"TST-002-AC-001","text":"second exists"}]), .stories[0]]
          | .coverage[0].storyIds=["TST-002","TST-001"] | .coverage[0].acceptanceCriteriaIds=["TST-002-AC-001","TST-001-AC-001"]' "$out" > "$tmp" && mv "$tmp" "$out" ;;
      source_hash)
        jq '.sourceHash="0000000000000000000000000000000000000000000000000000000000000000"' "$out" > "$tmp" && mv "$tmp" "$out" ;;
      invalid_json)
        printf '%s\n' 'not-json' > "$out" ;;
      empty_output)
        : > "$out" ;;
    esac
    ;;
  codex-decomposition-revision-schema.json)
    source_hash="$(printf '%s\n' "$prompt" | sed -n 's/^- Source hash: //p' | head -1)"
    base_hash="$(printf '%s\n' "$prompt" | sed -n 's/^- Base proposal hash: //p' | head -1)"
    review_hash="$(printf '%s\n' "$prompt" | sed -n 's/^- Prior review hash: //p' | head -1)"
    revision_attempt="$(printf '%s\n' "$prompt" | sed -n 's/^- Revision attempt: //p' | head -1)"
    decomposition_round="$(printf '%s\n' "$prompt" | sed -n 's/^- Decomposition round: \([0-9][0-9]*\) of.*/\1/p' | head -1)"
    findings="$(printf '%s\n' "$prompt" | sed -n 's/^- Outstanding finding IDs: //p' | head -1)"
    is_revision_repair=0
    printf '%s\n' "$prompt" | grep -q 'Machine-readable Revision Diagnostic' && is_revision_repair=1
    if [ -n "${FAKE_CAPTURE_DECOMPOSITION_PROMPTS_DIR:-}" ]; then
      mkdir -p "$FAKE_CAPTURE_DECOMPOSITION_PROMPTS_DIR"
      call_number="$(grep -Ec '^codex-decomposition(-revision)?-schema.json$' "$FAKE_PROJECT_DIR/.looper/test/stories/calls.log")"
      printf '%s\n' "$prompt" > "$FAKE_CAPTURE_DECOMPOSITION_PROMPTS_DIR/author-$call_number.txt"
    fi
    if [ "${FAKE_ASSERT_TARGETED_CONTEXT:-0}" = "1" ]; then
      printf '%s\n' "$prompt" | grep -q '## Immutable Base Proposal' || exit 81
      printf '%s\n' "$prompt" | grep -q '## Prior Adversarial Review' || exit 82
      printf '%s\n' "$prompt" | grep -q 'Clarify scope' || exit 83
      printf '%s\n' "$prompt" | grep -q 'not fresh decomposition' || exit 84
    fi
    if [ -n "${FAKE_TIMEOUT_ONCE_FILE:-}" ] && [ -f "$FAKE_TIMEOUT_ONCE_FILE" ] \
      && { [ -z "${FAKE_TIMEOUT_ROUND:-}" ] || [ "$decomposition_round" -eq "$FAKE_TIMEOUT_ROUND" ]; }; then
      rm -f "$FAKE_TIMEOUT_ONCE_FILE"
      sleep "${FAKE_TIMEOUT_SLEEP:-10}"
    fi
    base_json="$(printf '%s\n' "$prompt" | awk '/^## Immutable Base Proposal$/{section=1;next} section && /^```json$/{next} section && /^```$/{exit} section{print}')"
    base_story="$(jq '.stories[0] | .scope += ["Preserve the explicit unrelated-file boundary"] | .scope |= unique' <<<"$base_json")"
    defect="${FAKE_REVISION_DEFECT:-}"
    if [ "$is_revision_repair" = "1" ] && [ "${FAKE_REVISION_DEFECT_ALWAYS:-0}" != "1" ]; then defect=""; fi
    jq -n --arg sourceHash "$source_hash" --arg baseHash "$base_hash" --arg reviewHash "$review_hash" \
      --argjson findings "$findings" --argjson revisionAttempt "$revision_attempt" --argjson story "$base_story" '
      {sourceHash:$sourceHash,baseProposalHash:$baseHash,priorReviewHash:$reviewHash,findingIds:$findings,
       revisionAttempt:$revisionAttempt,summary:"Clarify only the reviewed scope boundary",topLevelReplacements:{},
       addSourceItems:[],replaceSourceItems:[],removeSourceItemIds:[],addStories:[],replaceStories:[$story],removeStoryIds:[],
       addCoverage:[],replaceCoverage:[],removeCoverageSourceIds:[]}' > "$out"
    tmp="${out}.tmp"
    case "$defect" in
      base_hash)
        jq '.baseProposalHash="0000000000000000000000000000000000000000000000000000000000000000"' "$out" > "$tmp" && mv "$tmp" "$out" ;;
      finding_ids)
        jq '.findingIds=["UNKNOWN"]' "$out" > "$tmp" && mv "$tmp" "$out" ;;
      unknown_story)
        jq '.replaceStories[0].id="TST-404"' "$out" > "$tmp" && mv "$tmp" "$out" ;;
      terminal_reason)
        jq '.topLevelReplacements.terminalReason="N/A"' "$out" > "$tmp" && mv "$tmp" "$out" ;;
      invalid_json)
        printf '%s\n' 'not-json' > "$out" ;;
    esac
    ;;
  codex-decomposition-review-schema.json)
    source_hash="$(printf '%s\n' "$prompt" | sed -n 's/^- Source hash: //p' | head -1)"
    proposal_hash="$(printf '%s\n' "$prompt" | sed -n 's/^- Proposal hash: //p' | head -1)"
    review_round="$(printf '%s\n' "$prompt" | sed -n 's/^- Review round: \([0-9][0-9]*\) of.*/\1/p' | head -1)"
    [ -n "$review_round" ] || review_round=1
    is_review_repair=0
    printf '%s\n' "$prompt" | grep -q '## Reviewer-output Repair Context' && is_review_repair=1
    if [ -n "${FAKE_CAPTURE_REVIEW_PROMPTS_DIR:-}" ]; then
      mkdir -p "$FAKE_CAPTURE_REVIEW_PROMPTS_DIR"
      call_number="$(grep -c '^codex-decomposition-review-schema.json$' "$FAKE_PROJECT_DIR/.looper/test/stories/calls.log")"
      printf '%s\n' "$prompt" > "$FAKE_CAPTURE_REVIEW_PROMPTS_DIR/reviewer-$call_number.txt"
    fi
    if [ -n "${FAKE_REVIEW_TIMEOUT_ONCE_FILE:-}" ] && [ -f "$FAKE_REVIEW_TIMEOUT_ONCE_FILE" ] \
      && { [ -z "${FAKE_REVIEW_TIMEOUT_ROUND:-}" ] || [ "$review_round" -eq "$FAKE_REVIEW_TIMEOUT_ROUND" ]; }; then
      rm -f "$FAKE_REVIEW_TIMEOUT_ONCE_FILE"
      sleep "${FAKE_REVIEW_TIMEOUT_SLEEP:-10}"
    fi
    if [ "$is_review_repair" = "1" ] && [ "${FAKE_REVIEW_REPAIR_SLEEP:-0}" -gt 0 ]; then sleep "$FAKE_REVIEW_REPAIR_SLEEP"; fi
    if [ "${FAKE_REVIEW_API_ERROR:-0}" = "1" ]; then echo 'HTTP 400 invalid_request_error: simulated reviewer schema rejection' >&2; exit 22; fi
    if [ "${FAKE_REVIEW_TRANSPORT_ERROR:-0}" = "1" ]; then echo 'connection reset by peer during reviewer call' >&2; exit 7; fi
    if [ "${FAKE_REVIEW_EMPTY:-0}" = "1" ]; then : > "$out"; exit 0; fi
    if [ "${FAKE_ASSERT_TARGETED_CONTEXT:-0}" = "1" ] && [ "$review_round" -gt 1 ]; then
      printf '%s\n' "$prompt" | grep -q '## Outstanding Prior Review' || exit 85
      printf '%s\n' "$prompt" | grep -q 'Clarify scope' || exit 86
      printf '%s\n' "$prompt" | grep -q 'Do not restart broad architectural review' || exit 87
      printf '%s\n' "$prompt" | grep -q '## Applied Stable-ID Revision' || exit 88
    fi
    if [ "${FAKE_REVIEW_NEEDS_HUMAN:-0}" = "1" ]; then
      jq -n --arg sh "$source_hash" --arg ph "$proposal_hash" '{sourceHash:$sh,proposalHash:$ph,verdict:"NEEDS_HUMAN",correctionClass:"HUMAN_DECISION",summary:"Material choice required",findings:[],sourceCoverage:[{sourceId:"REQ-001",status:"fail",details:"Ambiguous"}],storyEvaluation:[{storyId:"TST-001",status:"fail",details:"Blocked"}],terminalReason:"Choose the required behavior."}' > "$out"
    elif [ "${FAKE_REVIEW_ALWAYS_CHANGES:-0}" = "1" ] || { [ -n "${FAKE_DECOMPOSITION_CHANGES_ONCE_FILE:-}" ] && [ -f "$FAKE_DECOMPOSITION_CHANGES_ONCE_FILE" ]; }; then
      [ -z "${FAKE_DECOMPOSITION_CHANGES_ONCE_FILE:-}" ] || rm -f "$FAKE_DECOMPOSITION_CHANGES_ONCE_FILE"
      jq -n --arg sh "$source_hash" --arg ph "$proposal_hash" '{sourceHash:$sh,proposalHash:$ph,verdict:"CHANGES_REQUESTED",correctionClass:"MECHANICAL",summary:"Revise the boundaries",findings:[{id:"D-1",priority:"P1",details:"Clarify scope",evidence:"Requirement 1"}],sourceCoverage:[{sourceId:"REQ-001",status:"pass",details:"Covered"}],storyEvaluation:[{storyId:"TST-001",status:"fail",details:"Boundary needs revision"}],terminalReason:""}' > "$out"
    else
      jq -n --arg sh "$source_hash" --arg ph "$proposal_hash" '{sourceHash:$sh,proposalHash:$ph,verdict:"APPROVED",correctionClass:"NONE",summary:"Complete and bounded",findings:[],sourceCoverage:[{sourceId:"REQ-001",status:"pass",details:"Covered"}],storyEvaluation:[{storyId:"TST-001",status:"pass",details:"Independent and provable"}],terminalReason:""}' > "$out"
    fi
    defect="${FAKE_REVIEW_DEFECT:-}"
    if [ -n "${FAKE_REVIEW_DEFECT_ROUND:-}" ] && [ "$review_round" -ne "$FAKE_REVIEW_DEFECT_ROUND" ]; then defect=""; fi
    tmp="${out}.tmp"
    if [ "$is_review_repair" = "1" ] && [ "$defect" = "terminal_reason" ] && [ "${FAKE_REVIEW_DEFECT_ALWAYS:-0}" != "1" ]; then
      jq '.verdict="CHANGES_REQUESTED" | .correctionClass="MECHANICAL" | .findings=[{id:"D-R",priority:"P1",details:"Retain this substantive finding",evidence:"REQ-001"}] | .storyEvaluation[0].status="fail" | .terminalReason=""' "$out" > "$tmp" && mv "$tmp" "$out"
      defect=""
    elif [ "$is_review_repair" = "1" ] && [ "${FAKE_REVIEW_DEFECT_ALWAYS:-0}" != "1" ]; then
      defect=""
    fi
    case "$defect" in
      invalid_json) printf '%s\n' 'not-json' > "$out" ;;
      terminal_reason) jq '.verdict="CHANGES_REQUESTED" | .correctionClass="MECHANICAL" | .findings=[{id:"D-R",priority:"P1",details:"Retain this substantive finding",evidence:"REQ-001"}] | .storyEvaluation[0].status="fail" | .terminalReason="N/A"' "$out" > "$tmp" && mv "$tmp" "$out" ;;
      correction_class) jq '.correctionClass="MECHANICAL"' "$out" > "$tmp" && mv "$tmp" "$out" ;;
      incomplete_source) jq '.sourceCoverage=[]' "$out" > "$tmp" && mv "$tmp" "$out" ;;
      incomplete_story) jq '.storyEvaluation=[]' "$out" > "$tmp" && mv "$tmp" "$out" ;;
    esac
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

make_fake_claude() {
    local bin_dir="$1"
    mkdir -p "$bin_dir"
    cat > "$bin_dir/claude" <<'FAKE'
#!/bin/bash
set -euo pipefail
prompt="$(cat)"
schema=""
previous=""
for arg in "$@"; do
    if [ "$previous" = "--json-schema" ]; then schema="$arg"; fi
    previous="$arg"
done
if jq -e 'has("allOf") or has("oneOf") or has("anyOf")' <<<"$schema" >/dev/null; then
    echo 'HTTP 400 invalid_request_error: top-level composition keyword is unsupported' >&2
    exit 22
fi
if [ "${FAKE_CLAUDE_HTTP_400:-0}" = "1" ]; then
    echo 'HTTP 400 invalid_request_error: simulated schema/API rejection' >&2
    exit 22
fi
if [ "${FAKE_CLAUDE_TRANSPORT_ERROR:-0}" = "1" ]; then
    echo 'connection reset by peer while contacting Claude' >&2
    exit 7
fi
if [ "${FAKE_CLAUDE_EMPTY:-0}" = "1" ]; then
    printf '%s\n' '{"result":""}'
    exit 0
fi
echo 'HTTP 503 api_error: unconfigured fake Claude response' >&2
exit 23
FAKE
    chmod +x "$bin_dir/claude"
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
    install_runtime_fixture "$repo"
}

install_runtime_fixture() {
    local repo="$1" assets='[]' key source relative snapshot
    local root="$repo/.looper/test/runtime"
    mkdir -p "$root/bin" "$root/templates"
    while IFS=$'\t' read -r key source relative; do
        snapshot="$root/$relative"
        cp "$source" "$snapshot"
        assets="$(jq -n --argjson assets "$assets" --arg key "$key" --arg source "$source" --arg snapshot "$snapshot" \
          --arg hash "$(sha256sum "$snapshot" | awk '{print $1}')" '$assets + [{key:$key,sourcePath:$source,snapshotPath:$snapshot,sha256:$hash}]')"
    done <<EOF
executable	$SOURCE_DIR/bin/looper	bin/looper
sharedPrompt	$SOURCE_DIR/templates/prompt.shared.md	templates/prompt.shared.md
implementationPrompt	$SOURCE_DIR/templates/prompt.implementer.md	templates/prompt.implementer.md
implementationReviewPrompt	$SOURCE_DIR/templates/prompt.reviewer.md	templates/prompt.reviewer.md
implementationReviewSchema	$SOURCE_DIR/templates/codex-review-schema.json	templates/codex-review-schema.json
storiesSchema	$SOURCE_DIR/templates/stories.schema.json	templates/stories.schema.json
decomposerPrompt	$SOURCE_DIR/templates/prompt.decomposer.md	templates/prompt.decomposer.md
decompositionReviserPrompt	$SOURCE_DIR/templates/prompt.decomposition-reviser.md	templates/prompt.decomposition-reviser.md
decompositionReviewerPrompt	$SOURCE_DIR/templates/prompt.decomposition-reviewer.md	templates/prompt.decomposition-reviewer.md
decompositionSchema	$SOURCE_DIR/templates/codex-decomposition-schema.json	templates/codex-decomposition-schema.json
decompositionRevisionSchema	$SOURCE_DIR/templates/codex-decomposition-revision-schema.json	templates/codex-decomposition-revision-schema.json
decompositionReviewSchema	$SOURCE_DIR/templates/codex-decomposition-review-schema.json	templates/codex-decomposition-review-schema.json
plannerPrompt	$SOURCE_DIR/templates/prompt.planner.md	templates/prompt.planner.md
planReviewerPrompt	$SOURCE_DIR/templates/prompt.plan-reviewer.md	templates/prompt.plan-reviewer.md
planSchema	$SOURCE_DIR/templates/codex-plan-schema.json	templates/codex-plan-schema.json
planReviewSchema	$SOURCE_DIR/templates/codex-plan-review-schema.json	templates/codex-plan-review-schema.json
EOF
    jq -n --argjson assets "$assets" '{stateSchemaVersion:1,createdAt:"2026-01-01T00:00:00Z",assets:$assets}' > "$root/manifest.json"
    chmod +x "$root/bin/looper"
    if [ -f "$repo/.looper/test/decomposition/state.json" ]; then
        local state_tmp="$repo/.looper/test/decomposition/state.runtime.json"
        jq --arg hash "$(sha256sum "$root/manifest.json" | awk '{print $1}')" '.runtimeManifestHash=$hash' \
          "$repo/.looper/test/decomposition/state.json" > "$state_tmp"
        mv "$state_tmp" "$repo/.looper/test/decomposition/state.json"
    fi
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
    local repo="$TEST_TMP/decomp-revision" bin="$TEST_TMP/decomp-revision-bin" marker="$TEST_TMP/decomp-changes" prompts="$TEST_TMP/decomp-revision-prompts"
    make_source_repo "$repo"; make_fake_codex "$bin"; : > "$marker"
    run_source_command "$repo" "$bin" FAKE_DECOMPOSITION_CHANGES_ONCE_FILE="$marker" FAKE_ASSERT_TARGETED_CONTEXT=1 \
      FAKE_CAPTURE_DECOMPOSITION_PROMPTS_DIR="$prompts" "$SOURCE_DIR/bin/looper" prepare --spec request.md >/dev/null
    [ -f "$repo/.looper/test/decomposition/proposal-2.json" ] || fail "decomposition revision did not persist proposal 2"
    [ "$(grep -c '^codex-decomposition-review-schema.json$' "$repo/.looper/test/stories/calls.log")" -eq 2 ] || fail "decomposition revision was not re-reviewed"
    jq -e -n --slurpfile before "$repo/.looper/test/decomposition/proposal-1.json" --slurpfile after "$repo/.looper/test/decomposition/proposal-2.json" \
      '($before[0] | del(.stories[0].scope)) == ($after[0] | del(.stories[0].scope))
       and $before[0].stories[0].scope != $after[0].stories[0].scope' >/dev/null || fail "late-round revision changed previously accepted content"
    grep -q 'Clarify scope' "$prompts/author-2.txt" || fail "late-round author prompt omitted outstanding findings"
}

test_decomposition_needs_human() {
    local repo="$TEST_TMP/decomp-human" bin="$TEST_TMP/decomp-human-bin"
    make_source_repo "$repo"; make_fake_codex "$bin"
    if run_source_command "$repo" "$bin" FAKE_DECOMPOSITION_NEEDS_HUMAN=1 "$SOURCE_DIR/bin/looper" prepare --spec request.md >/dev/null 2>&1; then
        fail "NEEDS_HUMAN decomposition unexpectedly succeeded"
    fi
    [ "$(jq -r '.status' "$repo/.looper/test/decomposition/state.json")" = NEEDS_HUMAN ] || fail "NEEDS_HUMAN state was not persisted"
    [ ! -f "$repo/.looper/test/stories.json" ] || fail "NEEDS_HUMAN published stories"
    [ "$(grep -c '^codex-decomposition-schema.json$' "$repo/.looper/test/stories/calls.log")" -eq 1 ] || fail "genuine NEEDS_HUMAN was retried as an author-output defect"
    if grep -q '^codex-decomposition-review-schema.json$' "$repo/.looper/test/stories/calls.log"; then fail "author NEEDS_HUMAN reached adversarial review"; fi
}

test_reviewer_needs_human_and_review_limit() {
    local repo="$TEST_TMP/reviewer-human" bin="$TEST_TMP/reviewer-human-bin"
    make_source_repo "$repo"; make_fake_codex "$bin"
    if run_source_command "$repo" "$bin" FAKE_REVIEW_NEEDS_HUMAN=1 "$SOURCE_DIR/bin/looper" prepare --spec request.md >/dev/null 2>&1; then fail "reviewer NEEDS_HUMAN unexpectedly succeeded"; fi
    [ "$(jq -r '.status' "$repo/.looper/test/decomposition/state.json")" = NEEDS_HUMAN ] || fail "reviewer NEEDS_HUMAN was not persisted"
    [ ! -f "$repo/.looper/test/stories.json" ] || fail "reviewer NEEDS_HUMAN published stories"
}

test_reviewer_output_repair_matrix() {
    local defect code repo bin calls
    for defect in invalid_json correction_class incomplete_source incomplete_story; do
        code=INVALID_JSON
        [ "$defect" = correction_class ] && code=VERDICT_CORRECTION_CLASS_MISMATCH
        [ "$defect" = incomplete_source ] && code=INCOMPLETE_OR_DUPLICATE_SOURCE_COVERAGE
        [ "$defect" = incomplete_story ] && code=INCOMPLETE_OR_DUPLICATE_STORY_EVALUATION
        repo="$TEST_TMP/reviewer-repair-$defect"; bin="$TEST_TMP/reviewer-repair-$defect-bin"
        make_source_repo "$repo"; make_fake_codex "$bin"
        run_source_command "$repo" "$bin" FAKE_REVIEW_DEFECT="$defect" "$SOURCE_DIR/bin/looper" prepare --spec request.md >/dev/null
        jq -e --arg code "$code" 'any(.errors[]; .code==$code)' "$repo/.looper/test/decomposition/review-1-diagnostic-0.json" >/dev/null \
          || fail "$defect reviewer defect lacked diagnostic $code"
        [ "$(jq -r '.status' "$repo/.looper/test/decomposition/state.json")" = APPROVED ] || fail "$defect reviewer repair did not approve"
        [ "$(jq -r '.round' "$repo/.looper/test/decomposition/state.json")" = 1 ] || fail "$defect reviewer repair consumed a decomposition round"
        [ "$(jq -r '.reviewRepairAttempt' "$repo/.looper/test/decomposition/state.json")" = 1 ] || fail "$defect reviewer repair attempt was not preserved"
        [ "$(grep -c '^codex-decomposition-schema.json$' "$repo/.looper/test/stories/calls.log")" -eq 1 ] || fail "$defect reviewer repair reinvoked the author"
        [ "$(grep -c '^codex-decomposition-review-schema.json$' "$repo/.looper/test/stories/calls.log")" -eq 2 ] || fail "$defect reviewer repair invocation count changed"
        [ -f "$(jq -r '.reviewRawResponseFile' "$repo/.looper/test/decomposition/state.json")" ] || fail "$defect reviewer raw response was not preserved"
    done
}

test_reviewer_terminal_reason_repair_context() {
    local repo="$TEST_TMP/reviewer-context" bin="$TEST_TMP/reviewer-context-bin" marker="$TEST_TMP/reviewer-context-marker" prompts="$TEST_TMP/reviewer-context-prompts"
    make_source_repo "$repo"; make_fake_codex "$bin"; : > "$marker"
    run_source_command "$repo" "$bin" FAKE_DECOMPOSITION_CHANGES_ONCE_FILE="$marker" FAKE_REVIEW_DEFECT=terminal_reason \
      FAKE_REVIEW_DEFECT_ROUND=2 FAKE_CAPTURE_REVIEW_PROMPTS_DIR="$prompts" LOOPER_DECOMPOSITION_REVIEW_MAX_ROUNDS=2 \
      "$SOURCE_DIR/bin/looper" prepare --spec request.md >/dev/null 2>&1 || true
    jq -e 'any(.errors[]; .code=="TERMINAL_REASON_FORBIDDEN")' "$repo/.looper/test/decomposition/review-2-diagnostic-0.json" >/dev/null \
      || fail "review terminalReason defect lacked its exact diagnostic"
    grep -q '## Proposed Decomposition' "$prompts/reviewer-3.txt" || fail "review repair omitted immutable proposal context"
    grep -q '## Outstanding Prior Review' "$prompts/reviewer-3.txt" || fail "review repair omitted associated prior review"
    grep -q 'Clarify scope' "$prompts/reviewer-3.txt" || fail "review repair omitted outstanding prior findings"
    grep -q 'Retain this substantive finding' "$prompts/reviewer-3.txt" || fail "review repair omitted the parseable invalid finding"
    grep -q 'TERMINAL_REASON_FORBIDDEN' "$prompts/reviewer-3.txt" || fail "review repair omitted machine-readable diagnostics"
    [ "$(jq -r '.status' "$repo/.looper/test/decomposition/state.json")" = CORRECTABLE_REVIEW_LIMIT ] || fail "corrected mechanical review did not use the normal correctable limit state"
    [ "$(jq -r '.round' "$repo/.looper/test/decomposition/state.json")" = 3 ] || fail "reviewer repair consumed an extra decomposition round"
}

test_reviewer_repair_limit_and_resume() {
    local repo="$TEST_TMP/reviewer-repair-limit" bin="$TEST_TMP/reviewer-repair-limit-bin" calls state="" pid child diagnostic
    make_source_repo "$repo"; make_fake_codex "$bin"
    if run_source_command "$repo" "$bin" FAKE_REVIEW_DEFECT=correction_class FAKE_REVIEW_DEFECT_ALWAYS=1 \
      LOOPER_DECOMPOSITION_REVIEW_OUTPUT_REPAIR_MAX_ATTEMPTS=2 "$SOURCE_DIR/bin/looper" prepare --spec request.md >/dev/null 2>&1; then
        fail "exhausted reviewer repairs unexpectedly succeeded"
    fi
    [ "$(jq -r '.status' "$repo/.looper/test/decomposition/state.json")" = DECOMPOSITION_REVIEW_OUTPUT_INVALID ] || fail "reviewer repair exhaustion became a human stop"
    [ "$(jq -r '.reviewRepairAttempt' "$repo/.looper/test/decomposition/state.json")" = 2 ] || fail "reviewer repair exhaustion lost its exact attempt"
    [ "$(grep -c '^codex-decomposition-schema.json$' "$repo/.looper/test/stories/calls.log")" -eq 1 ] || fail "reviewer exhaustion reinvoked the author"
    [ "$(grep -c '^codex-decomposition-review-schema.json$' "$repo/.looper/test/stories/calls.log")" -eq 3 ] || fail "reviewer repair limit call count changed"
    [ ! -f "$repo/.looper/test/stories.json" ] || fail "invalid reviewer output published stories"

    repo="$TEST_TMP/reviewer-repair-resume"; bin="$TEST_TMP/reviewer-repair-resume-bin"
    make_source_repo "$repo"; make_fake_codex "$bin"
    (run_source_command "$repo" "$bin" FAKE_REVIEW_DEFECT=correction_class FAKE_REVIEW_REPAIR_SLEEP=10 \
      "$SOURCE_DIR/bin/looper" prepare --spec request.md) >/dev/null 2>&1 & pid=$!
    for _ in $(seq 1 100); do
        [ -f "$repo/.looper/test/decomposition/state.json" ] && state="$(jq -r '.status // empty' "$repo/.looper/test/decomposition/state.json" 2>/dev/null || true)"
        [ "$state" = REVIEW_OUTPUT_REPAIR_REQUIRED ] && break
        sleep 0.05
    done
    [ "$state" = REVIEW_OUTPUT_REPAIR_REQUIRED ] || { kill "$pid" >/dev/null 2>&1 || true; fail "reviewer repair did not reach resumable boundary"; }
    child="$(pgrep -P "$pid" 2>/dev/null || true)"; kill -TERM "$pid" >/dev/null 2>&1 || true
    for child in $child; do pkill -TERM -P "$child" >/dev/null 2>&1 || true; kill -TERM "$child" >/dev/null 2>&1 || true; done
    wait "$pid" 2>/dev/null || true
    run_source_command "$repo" "$bin" FAKE_REVIEW_DEFECT=correction_class "$SOURCE_DIR/bin/looper" prepare --spec request.md >/dev/null
    [ "$(jq -r '.reviewRepairAttempt' "$repo/.looper/test/decomposition/state.json")" = 1 ] || fail "reviewer repair resume consumed another attempt"
    calls="$(wc -l < "$repo/.looper/test/stories/calls.log")"; diagnostic="$(jq -r '.reviewDiagnosticFile' "$repo/.looper/test/decomposition/state.json")"
    printf '\ntampered\n' >> "$diagnostic"
    if run_source_command "$repo" "$bin" "$SOURCE_DIR/bin/looper" run 1 >/dev/null 2>&1; then fail "tampered reviewer diagnostic passed provenance verification"; fi
    [ "$(wc -l < "$repo/.looper/test/stories/calls.log")" -eq "$calls" ] || fail "tampered reviewer diagnostic reached another agent"
}

test_reviewer_timeout_and_transport_failures() {
    local repo="$TEST_TMP/reviewer-timeout" bin="$TEST_TMP/reviewer-timeout-bin" marker="$TEST_TMP/reviewer-timeout-marker" review_marker="$TEST_TMP/reviewer-timeout-review" prompts="$TEST_TMP/reviewer-timeout-prompts" calls diagnostic
    make_source_repo "$repo"; make_fake_codex "$bin"; : > "$marker"; : > "$review_marker"
    run_source_command "$repo" "$bin" FAKE_REVIEW_TIMEOUT_ONCE_FILE="$marker" FAKE_REVIEW_TIMEOUT_SLEEP=10 \
      FAKE_REVIEW_TIMEOUT_ROUND=2 FAKE_DECOMPOSITION_CHANGES_ONCE_FILE="$review_marker" FAKE_CAPTURE_REVIEW_PROMPTS_DIR="$prompts" \
      LOOPER_DECOMPOSITION_AGENT_TIMEOUT_SECONDS=1 "$SOURCE_DIR/bin/looper" prepare --spec request.md >/dev/null
    [ "$(jq -r '.round' "$repo/.looper/test/decomposition/state.json")" = 2 ] || fail "reviewer timeout consumed a decomposition round"
    [ "$(jq -r '.reviewRepairAttempt' "$repo/.looper/test/decomposition/state.json")" = 0 ] || fail "reviewer timeout consumed a semantic repair attempt"
    [ "$(jq -r '.reviewTimeoutAttempt' "$repo/.looper/test/decomposition/state.json")" = 1 ] || fail "reviewer timeout retry attempt was not preserved"
    diagnostic="$(jq -r '.reviewAgentFailureFile' "$repo/.looper/test/decomposition/state.json")"
    jq -e '.failureType=="AGENT_TIMEOUT" and .timedOut==true' "$diagnostic" >/dev/null || fail "reviewer timeout diagnostic was lost"
    [ "$(grep -Ec '^codex-decomposition(-revision)?-schema.json$' "$repo/.looper/test/stories/calls.log")" -eq 2 ] || fail "reviewer timeout reinvoked the author"
    [ "$(grep -c '^codex-decomposition-review-schema.json$' "$repo/.looper/test/stories/calls.log")" -eq 3 ] || fail "reviewer timeout retry call count changed"
    grep -q '## Outstanding Prior Review' "$prompts/reviewer-3.txt" || fail "reviewer timeout retry omitted prior review context"
    grep -q 'Clarify scope' "$prompts/reviewer-3.txt" || fail "reviewer timeout retry omitted outstanding findings"
    grep -q 'Timed-out Reviewer Invocation Diagnostic' "$prompts/reviewer-3.txt" || fail "reviewer timeout retry omitted its exact diagnostic"

    for failure in API TRANSPORT; do
        if [ "$failure" = API ]; then repo="$TEST_TMP/reviewer-api"; bin="$TEST_TMP/reviewer-api-bin"; else repo="$TEST_TMP/reviewer-transport"; bin="$TEST_TMP/reviewer-transport-bin"; fi
        make_source_repo "$repo"; make_fake_codex "$bin"
        if [ "$failure" = API ]; then
            run_source_command "$repo" "$bin" FAKE_REVIEW_API_ERROR=1 "$SOURCE_DIR/bin/looper" prepare --spec request.md >/dev/null 2>&1 || true
            diagnostic="$repo/.looper/test/decomposition/review-1-attempt-0-agent-0.json"
            jq -e '.failureType=="AGENT_API_ERROR" and .apiStatus=="400"' "$diagnostic" >/dev/null || fail "reviewer API failure was misclassified"
        else
            run_source_command "$repo" "$bin" FAKE_REVIEW_TRANSPORT_ERROR=1 "$SOURCE_DIR/bin/looper" prepare --spec request.md >/dev/null 2>&1 || true
            diagnostic="$repo/.looper/test/decomposition/review-1-attempt-0-agent-0.json"
            jq -e '.failureType=="AGENT_TRANSPORT_ERROR"' "$diagnostic" >/dev/null || fail "reviewer transport failure was misclassified"
        fi
        [ "$(jq -r '.status' "$repo/.looper/test/decomposition/state.json")" = DECOMPOSITION_REVIEW_AGENT_FAILED ] || fail "reviewer $failure failure used an output-repair state"
        [ "$(grep -c '^codex-decomposition-review-schema.json$' "$repo/.looper/test/stories/calls.log")" -eq 1 ] || fail "reviewer $failure failure was retried"
    done

    repo="$TEST_TMP/reviewer-empty"; bin="$TEST_TMP/reviewer-empty-bin"
    make_source_repo "$repo"; make_fake_codex "$bin"
    run_source_command "$repo" "$bin" FAKE_REVIEW_EMPTY=1 "$SOURCE_DIR/bin/looper" prepare --spec request.md >/dev/null 2>&1 || true
    diagnostic="$repo/.looper/test/decomposition/review-1-attempt-0-agent-0.json"
    jq -e '.failureType=="EMPTY_AGENT_OUTPUT" and .processExitStatus==0 and .structuredOutputPresent==false' "$diagnostic" >/dev/null \
      || fail "empty reviewer output was not distinguished from semantic and transport failures"
    [ "$(jq -r '.status' "$repo/.looper/test/decomposition/state.json")" = DECOMPOSITION_REVIEW_AGENT_FAILED ] || fail "empty reviewer output entered semantic repair"
}

test_runtime_pinning_and_tamper() {
    local repo="$TEST_TMP/runtime-pin" bin="$TEST_TMP/runtime-pin-bin" live="$TEST_TMP/runtime-live" override="$TEST_TMP/override-reviewer.md" calls snapshot
    make_source_repo "$repo"; make_fake_codex "$bin"; mkdir -p "$live/bin"; cp -R "$SOURCE_DIR/templates" "$live/templates"; cp "$SOURCE_DIR/bin/looper" "$live/bin/looper"; chmod +x "$live/bin/looper"
    cp "$SOURCE_DIR/templates/prompt.decomposition-reviewer.md" "$override"; printf '\nCaptured override marker.\n' >> "$override"
    run_source_command "$repo" "$bin" FAKE_REVIEW_ALWAYS_CHANGES=1 LOOPER_DECOMPOSITION_REVIEW_MAX_ROUNDS=1 LOOPER_DECOMPOSITION_REVIEW_PROMPT_FILE="$override" \
      "$live/bin/looper" prepare --spec request.md >/dev/null 2>&1 || true
    snapshot="$(jq -r '.assets[] | select(.key=="decompositionReviewerPrompt") | .snapshotPath' "$repo/.looper/test/runtime/manifest.json")"
    [ "$(jq -r '.assets[] | select(.key=="decompositionReviewerPrompt") | .sourcePath' "$repo/.looper/test/runtime/manifest.json")" = "$override" ] || fail "runtime manifest lost overridden prompt source"
    grep -q 'Captured override marker' "$snapshot" || fail "runtime snapshot did not capture overridden prompt content"
    printf '\nexit 97\n' >> "$live/bin/looper"
    run_source_command "$repo" "$bin" LOOPER_DECOMPOSITION_REVIEW_MAX_ROUNDS=2 "$live/bin/looper" prepare --spec request.md >/dev/null \
      || fail "live Looper edit changed an already-started run"
    [ "$(jq -r '.status' "$repo/.looper/test/decomposition/state.json")" = APPROVED ] || fail "pinned runtime did not finish correctable-limit resume"

    repo="$TEST_TMP/runtime-tamper"; bin="$TEST_TMP/runtime-tamper-bin"
    make_source_repo "$repo"; make_fake_codex "$bin"
    run_source_command "$repo" "$bin" FAKE_REVIEW_ALWAYS_CHANGES=1 LOOPER_DECOMPOSITION_REVIEW_MAX_ROUNDS=1 \
      "$SOURCE_DIR/bin/looper" prepare --spec request.md >/dev/null 2>&1 || true
    calls="$(wc -l < "$repo/.looper/test/stories/calls.log")"
    snapshot="$(jq -r '.assets[] | select(.key=="decompositionReviewerPrompt") | .snapshotPath' "$repo/.looper/test/runtime/manifest.json")"
    chmod u+w "$snapshot"; printf '\ntampered\n' >> "$snapshot"
    if run_source_command "$repo" "$bin" LOOPER_DECOMPOSITION_REVIEW_MAX_ROUNDS=2 "$SOURCE_DIR/bin/looper" prepare --spec request.md >/dev/null 2>&1; then fail "tampered runtime snapshot resumed"; fi
    [ "$(wc -l < "$repo/.looper/test/stories/calls.log")" -eq "$calls" ] || fail "tampered runtime reached an agent"
}

test_repair_prompt_preserves_review_context() {
    local repo="$TEST_TMP/repair-context" bin="$TEST_TMP/repair-context-bin" marker="$TEST_TMP/repair-context-review" prompts="$TEST_TMP/repair-context-prompts"
    make_source_repo "$repo"; make_fake_codex "$bin"; : > "$marker"
    run_source_command "$repo" "$bin" FAKE_DECOMPOSITION_CHANGES_ONCE_FILE="$marker" \
      FAKE_REVISION_DEFECT=base_hash \
      FAKE_CAPTURE_DECOMPOSITION_PROMPTS_DIR="$prompts" "$SOURCE_DIR/bin/looper" prepare --spec request.md >/dev/null
    [ "$(jq -r '.status' "$repo/.looper/test/decomposition/state.json")" = APPROVED ] || fail "context-preserving repair did not approve"
    [ "$(jq -r '.round' "$repo/.looper/test/decomposition/state.json")" = 2 ] || fail "same-round repair changed the review round"
    [ "$(jq -r '.repairAttempt' "$repo/.looper/test/decomposition/state.json")" = 1 ] || fail "same-round repair attempt was not recorded"
    grep -q '## Immutable Base Proposal' "$prompts/author-3.txt" || fail "repair prompt omitted the last valid proposal"
    grep -q '## Prior Adversarial Review' "$prompts/author-3.txt" || fail "repair prompt omitted the associated review"
    grep -q 'Clarify scope' "$prompts/author-3.txt" || fail "repair prompt omitted the outstanding review finding"
    grep -q 'REVISION_BASE_HASH_MISMATCH' "$prompts/author-3.txt" || fail "repair prompt omitted the exact output diagnostic"
    grep -q 'Invalid Revision Output' "$prompts/author-3.txt" || fail "repair prompt omitted the invalid candidate"
}

test_delta_revision_validation_and_apply() {
    local defect code repo bin marker base_hash calls
    for defect in finding_ids unknown_story terminal_reason; do
        code=REVISION_FINDINGS_MISMATCH
        [ "$defect" = unknown_story ] && code=REPLACE_STORY_UNKNOWN
        [ "$defect" = terminal_reason ] && code=PROPOSED_HAS_TERMINAL_REASON
        repo="$TEST_TMP/delta-$defect"; bin="$TEST_TMP/delta-$defect-bin"; marker="$TEST_TMP/delta-$defect-review"
        make_source_repo "$repo"; make_fake_codex "$bin"; : > "$marker"
        run_source_command "$repo" "$bin" FAKE_DECOMPOSITION_CHANGES_ONCE_FILE="$marker" FAKE_REVISION_DEFECT="$defect" \
          "$SOURCE_DIR/bin/looper" prepare --spec request.md >/dev/null
        jq -e --arg code "$code" 'any(.errors[]; .code==$code)' "$repo/.looper/test/decomposition/revision-2-diagnostic-0.json" >/dev/null || fail "$defect revision lacked diagnostic $code"
        [ "$(jq -r '.round' "$repo/.looper/test/decomposition/state.json")" = 2 ] || fail "$defect revision repair consumed a review round"
        [ "$(jq -r '.revisionAttempt' "$repo/.looper/test/decomposition/state.json")" = 1 ] || fail "$defect revision repair attempt was not persisted"
        [ -f "$repo/.looper/test/decomposition/revision-2-attempt-0.json" ] || fail "$defect invalid revision was not preserved"
        [ -f "$repo/.looper/test/decomposition/revision-2-attempt-1.json" ] || fail "$defect corrected revision was not preserved"
        jq -e '((has("sourceInventory"))|not) and (.replaceStories|length)==1 and (.addStories|length)==0' \
          "$repo/.looper/test/decomposition/revision-2-attempt-1.json" >/dev/null || fail "$defect author returned a full proposal instead of a delta"
        base_hash="$(sha256sum "$repo/.looper/test/decomposition/proposal-1.json" | awk '{print $1}')"
        [ "$base_hash" = "$(jq -r '.baseProposalHash' "$repo/.looper/test/decomposition/revision-2-attempt-1.json")" ] || fail "$defect revision was not bound to the immutable base"
    done
    calls="$(wc -l < "$repo/.looper/test/stories/calls.log")"
    printf '\n' >> "$(jq -r '.revisionFile' "$repo/.looper/test/decomposition/state.json")"
    if run_source_command "$repo" "$bin" "$SOURCE_DIR/bin/looper" run 1 >/dev/null 2>&1; then fail "tampered approved revision passed provenance verification"; fi
    [ "$(wc -l < "$repo/.looper/test/stories/calls.log")" -eq "$calls" ] || fail "tampered revision reached downstream agents"
}

test_agent_api_and_empty_output_failures() {
    local repo="$TEST_TMP/claude-api" bin="$TEST_TMP/claude-api-bin" diagnostic
    jq -e '(has("allOf") or has("oneOf") or has("anyOf"))|not' "$SOURCE_DIR/templates/codex-decomposition-schema.json" >/dev/null || fail "full Claude decomposition schema uses unsupported top-level composition"
    jq -e '(has("allOf") or has("oneOf") or has("anyOf"))|not' "$SOURCE_DIR/templates/codex-decomposition-revision-schema.json" >/dev/null || fail "Claude revision schema uses unsupported top-level composition"
    jq -e '(has("allOf") or has("oneOf") or has("anyOf"))|not' "$SOURCE_DIR/templates/codex-decomposition-review-schema.json" >/dev/null || fail "Claude reviewer schema uses unsupported top-level composition"
    make_source_repo "$repo"; make_fake_codex "$bin"; make_fake_claude "$bin"
    if run_source_command "$repo" "$bin" LOOPER_IMPLEMENTATION_AGENT=claude FAKE_CLAUDE_HTTP_400=1 \
      "$SOURCE_DIR/bin/looper" prepare --spec request.md >/dev/null 2>&1; then fail "Claude HTTP 400 unexpectedly succeeded"; fi
    diagnostic="$repo/.looper/test/decomposition/proposal-1-attempt-0-agent-0.json"
    [ "$(jq -r '.status' "$repo/.looper/test/decomposition/state.json")" = DECOMPOSITION_AGENT_FAILED ] || fail "Claude API error did not use the agent-failure state"
    jq -e '.failureType=="AGENT_API_ERROR" and .apiStatus=="400" and (.message|contains("simulated schema/API rejection"))
      and .processExitStatus==22 and .timedOut==false and .structuredOutputPresent==false' "$diagnostic" >/dev/null || fail "Claude API diagnostic lost the original failure"
    [ -f "$(jq -r '.rawResponsePath' "$diagnostic")" ] || fail "Claude API diagnostic did not preserve its raw response"
    [ ! -f "$repo/.looper/test/stories.json" ] || fail "Claude API failure published stories"

    repo="$TEST_TMP/claude-transport"; bin="$TEST_TMP/claude-transport-bin"
    make_source_repo "$repo"; make_fake_codex "$bin"; make_fake_claude "$bin"
    if run_source_command "$repo" "$bin" LOOPER_IMPLEMENTATION_AGENT=claude FAKE_CLAUDE_TRANSPORT_ERROR=1 \
      "$SOURCE_DIR/bin/looper" prepare --spec request.md >/dev/null 2>&1; then fail "Claude transport failure unexpectedly succeeded"; fi
    diagnostic="$repo/.looper/test/decomposition/proposal-1-attempt-0-agent-0.json"
    jq -e '.failureType=="AGENT_TRANSPORT_ERROR" and .processExitStatus==7 and (.message|contains("connection reset by peer"))' "$diagnostic" >/dev/null || fail "transport failure was not preserved distinctly"

    repo="$TEST_TMP/empty-output"; bin="$TEST_TMP/empty-output-bin"
    make_source_repo "$repo"; make_fake_codex "$bin"
    if run_source_command "$repo" "$bin" FAKE_DECOMPOSITION_DEFECT=empty_output "$SOURCE_DIR/bin/looper" prepare --spec request.md >/dev/null 2>&1; then fail "empty successful output unexpectedly succeeded"; fi
    diagnostic="$repo/.looper/test/decomposition/proposal-1-attempt-0-agent-0.json"
    jq -e '.failureType=="EMPTY_AGENT_OUTPUT" and .processExitStatus==0 and .timedOut==false and .structuredOutputPresent==false' "$diagnostic" >/dev/null || fail "empty output was not distinguished from transport and JSON failures"
    [ "$(grep -c '^codex-decomposition-schema.json$' "$repo/.looper/test/stories/calls.log")" -eq 1 ] || fail "empty output was retried as a semantic defect"
}

test_timeout_retry_preserves_review_context() {
    local repo="$TEST_TMP/timeout-retry" bin="$TEST_TMP/timeout-retry-bin" marker="$TEST_TMP/timeout-once" review_marker="$TEST_TMP/timeout-review" prompts="$TEST_TMP/timeout-prompts" diagnostic
    make_source_repo "$repo"; make_fake_codex "$bin"; : > "$marker"; : > "$review_marker"
    run_source_command "$repo" "$bin" FAKE_TIMEOUT_ONCE_FILE="$marker" FAKE_TIMEOUT_ROUND=2 FAKE_TIMEOUT_SLEEP=10 \
      FAKE_DECOMPOSITION_CHANGES_ONCE_FILE="$review_marker" FAKE_CAPTURE_DECOMPOSITION_PROMPTS_DIR="$prompts" \
      LOOPER_DECOMPOSITION_AGENT_TIMEOUT_SECONDS=1 LOOPER_DECOMPOSITION_TIMEOUT_MAX_RETRIES=1 \
      "$SOURCE_DIR/bin/looper" prepare --spec request.md >/dev/null
    [ "$(jq -r '.status' "$repo/.looper/test/decomposition/state.json")" = APPROVED ] || fail "timeout retry did not recover"
    [ "$(jq -r '.round' "$repo/.looper/test/decomposition/state.json")" = 2 ] || fail "timeout retry consumed a decomposition review round"
    [ "$(jq -r '.repairAttempt' "$repo/.looper/test/decomposition/state.json")" = 0 ] || fail "timeout retry consumed an author-content repair attempt"
    [ "$(jq -r '.timeoutAttempt' "$repo/.looper/test/decomposition/state.json")" = 1 ] || fail "timeout retry attempt was not persisted"
    diagnostic="$(jq -r '.agentFailureFile' "$repo/.looper/test/decomposition/state.json")"
    jq -e '.failureType=="AGENT_TIMEOUT" and .timedOut==true and .processExitStatus==124' "$diagnostic" >/dev/null || fail "timeout diagnostic was not preserved"
    grep -q '## Immutable Base Proposal' "$prompts/author-3.txt" || fail "timeout retry omitted the prior valid proposal"
    grep -q '## Prior Adversarial Review' "$prompts/author-3.txt" || fail "timeout retry omitted the prior review"
    grep -q 'Clarify scope' "$prompts/author-3.txt" || fail "timeout retry omitted the exact outstanding finding"
    grep -q 'Timed-out Invocation Diagnostic' "$prompts/author-3.txt" || fail "timeout retry omitted its transport diagnostic"
}

test_correctable_review_limit_resume() {
    local repo="$TEST_TMP/correctable-limit" bin="$TEST_TMP/correctable-limit-bin" proposal_hash review_hash calls
    make_source_repo "$repo"; make_fake_codex "$bin"
    if run_source_command "$repo" "$bin" FAKE_REVIEW_ALWAYS_CHANGES=1 LOOPER_DECOMPOSITION_REVIEW_MAX_ROUNDS=1 \
      "$SOURCE_DIR/bin/looper" prepare --spec request.md >/dev/null 2>&1; then fail "correctable review limit unexpectedly succeeded"; fi
    [ "$(jq -r '.status' "$repo/.looper/test/decomposition/state.json")" = CORRECTABLE_REVIEW_LIMIT ] || fail "correctable findings were mislabeled as a human or generic review stop"
    [ "$(jq -r '.round' "$repo/.looper/test/decomposition/state.json")" = 2 ] || fail "correctable limit did not preserve the next round"
    proposal_hash="$(jq -r '.contextProposalHash' "$repo/.looper/test/decomposition/state.json")"
    review_hash="$(jq -r '.contextReviewHash' "$repo/.looper/test/decomposition/state.json")"
    [ "$proposal_hash" = "$(sha256sum "$repo/.looper/test/decomposition/proposal-1.json" | awk '{print $1}')" ] || fail "correctable limit lost proposal provenance"
    [ "$review_hash" = "$(sha256sum "$repo/.looper/test/decomposition/review-1.json" | awk '{print $1}')" ] || fail "correctable limit lost review provenance"
    run_source_command "$repo" "$bin" LOOPER_DECOMPOSITION_REVIEW_MAX_ROUNDS=2 FAKE_ASSERT_TARGETED_CONTEXT=1 \
      "$SOURCE_DIR/bin/looper" prepare --spec request.md >/dev/null
    [ "$(jq -r '.status' "$repo/.looper/test/decomposition/state.json")" = APPROVED ] || fail "higher review limit did not resume from the correctable boundary"

    repo="$TEST_TMP/correctable-limit-tamper"; bin="$TEST_TMP/correctable-limit-tamper-bin"
    make_source_repo "$repo"; make_fake_codex "$bin"
    run_source_command "$repo" "$bin" FAKE_REVIEW_ALWAYS_CHANGES=1 LOOPER_DECOMPOSITION_REVIEW_MAX_ROUNDS=1 \
      "$SOURCE_DIR/bin/looper" prepare --spec request.md >/dev/null 2>&1 || true
    calls="$(wc -l < "$repo/.looper/test/stories/calls.log")"
    printf '\n' >> "$repo/.looper/test/decomposition/proposal-1.json"
    if run_source_command "$repo" "$bin" LOOPER_DECOMPOSITION_REVIEW_MAX_ROUNDS=2 "$SOURCE_DIR/bin/looper" prepare --spec request.md >/dev/null 2>&1; then fail "tampered correctable-limit context resumed"; fi
    [ "$(wc -l < "$repo/.looper/test/stories/calls.log")" -eq "$calls" ] || fail "tampered context reached an agent before hash verification"

    repo="$TEST_TMP/correctable-review-tamper"; bin="$TEST_TMP/correctable-review-tamper-bin"
    make_source_repo "$repo"; make_fake_codex "$bin"
    run_source_command "$repo" "$bin" FAKE_REVIEW_ALWAYS_CHANGES=1 LOOPER_DECOMPOSITION_REVIEW_MAX_ROUNDS=1 \
      "$SOURCE_DIR/bin/looper" prepare --spec request.md >/dev/null 2>&1 || true
    calls="$(wc -l < "$repo/.looper/test/stories/calls.log")"
    printf '\n' >> "$repo/.looper/test/decomposition/review-1.json"
    if run_source_command "$repo" "$bin" LOOPER_DECOMPOSITION_REVIEW_MAX_ROUNDS=2 "$SOURCE_DIR/bin/looper" prepare --spec request.md >/dev/null 2>&1; then fail "tampered correctable-limit review resumed"; fi
    [ "$(wc -l < "$repo/.looper/test/stories/calls.log")" -eq "$calls" ] || fail "tampered review reached an agent before hash verification"
}

test_repair_diagnostic_provenance() {
    local repo="$TEST_TMP/repair-diagnostic-tamper" bin="$TEST_TMP/repair-diagnostic-tamper-bin" calls diagnostic
    make_source_repo "$repo"; make_fake_codex "$bin"
    run_source_command "$repo" "$bin" FAKE_DECOMPOSITION_DEFECT=terminal_reason "$SOURCE_DIR/bin/looper" prepare --spec request.md >/dev/null
    diagnostic="$repo/.looper/test/decomposition/proposal-1-diagnostic-0.json"
    calls="$(wc -l < "$repo/.looper/test/stories/calls.log")"
    printf '\n' >> "$diagnostic"
    if run_source_command "$repo" "$bin" "$SOURCE_DIR/bin/looper" run 1 >/dev/null 2>&1; then fail "tampered repair diagnostic passed provenance verification"; fi
    [ "$(wc -l < "$repo/.looper/test/stories/calls.log")" -eq "$calls" ] || fail "tampered repair diagnostic reached downstream agents"
}

assert_output_repair() {
    local defect="$1" expected_code="$2" repo="$TEST_TMP/repair-$1" bin="$TEST_TMP/repair-$1-bin" diagnostic
    make_source_repo "$repo"; make_fake_codex "$bin"
    run_source_command "$repo" "$bin" FAKE_DECOMPOSITION_DEFECT="$defect" "$SOURCE_DIR/bin/looper" prepare --spec request.md >/dev/null
    diagnostic="$repo/.looper/test/decomposition/proposal-1-diagnostic-0.json"
    if ! jq -e --arg code "$expected_code" 'any(.errors[]; .code==$code)' "$diagnostic" >/dev/null; then
        jq -r '.errors[] | "\(.code): \(.message)"' "$diagnostic" >&2
        fail "$defect lacked diagnostic $expected_code"
    fi
    if [ "$expected_code" = "INVALID_JSON" ]; then
        [ "$(jq -r '.failureType' "$diagnostic")" = INVALID_JSON ] || fail "$defect was not classified as malformed JSON"
    else
        [ "$(jq -r '.failureType' "$diagnostic")" = SEMANTIC_VALIDATION_FAILED ] || fail "$defect was not classified as a semantic validation failure"
    fi
    [ "$(jq -r '.status' "$repo/.looper/test/decomposition/state.json")" = APPROVED ] || fail "$defect repair did not approve"
    [ "$(jq -r '.round' "$repo/.looper/test/decomposition/state.json")" = 1 ] || fail "$defect repair consumed a review round"
    [ "$(jq -r '.repairAttempt' "$repo/.looper/test/decomposition/state.json")" = 1 ] || fail "$defect repair attempt was not persisted"
    [ "$(grep -c '^codex-decomposition-schema.json$' "$repo/.looper/test/stories/calls.log")" -eq 2 ] || fail "$defect did not use exactly one same-round repair"
    [ "$(grep -c '^codex-decomposition-review-schema.json$' "$repo/.looper/test/stories/calls.log")" -eq 1 ] || fail "$defect invoked the reviewer before correction or consumed a review round"
    [ -f "$repo/.looper/test/decomposition/proposal-1-attempt-0.json" ] || fail "$defect invalid proposal was not preserved"
    [ -f "$repo/.looper/test/decomposition/proposal-1-attempt-1.json" ] || fail "$defect corrected proposal was not preserved"
    [ "$(sha256sum "$repo/.looper/test/decomposition/proposal-1-attempt-0.json" | awk '{print $1}')" = "$(jq -r '.invalidProposalHash' "$repo/.looper/test/decomposition/state.json")" ] || fail "$defect invalid proposal hash was not preserved"
    [ "$(sha256sum "$diagnostic" | awk '{print $1}')" = "$(jq -r '.diagnosticHash' "$repo/.looper/test/decomposition/state.json")" ] || fail "$defect diagnostic hash was not preserved"
    [ "$(sha256sum "$repo/.looper/test/decomposition/proposal-1-attempt-1.json" | awk '{print $1}')" = "$(jq -r '.correctedProposalHash' "$repo/.looper/test/decomposition/state.json")" ] || fail "$defect corrected proposal hash was not preserved"
}

test_output_repair_disposition_fields() {
    assert_output_repair terminal_reason PROPOSED_HAS_TERMINAL_REASON
    assert_output_repair unresolved_questions PROPOSED_HAS_UNRESOLVED_QUESTIONS
    jq -e 'any(.errors[]; .code=="PROPOSED_HAS_TERMINAL_REASON" and .message=="PROPOSED requires terminalReason=\"\" but received \"N/A\"")' \
      "$TEST_TMP/repair-terminal_reason/.looper/test/decomposition/proposal-1-diagnostic-0.json" >/dev/null || fail "terminalReason diagnostic was not actionable"
}

test_output_repair_references_and_ids() {
    local pair defect code
    for pair in \
      'source_refs STORY_SOURCE_REFS_MISMATCH' \
      'duplicate_inventory DUPLICATE_SOURCE_ID' \
      'duplicate_story DUPLICATE_STORY_ID' \
      'duplicate_acceptance DUPLICATE_ACCEPTANCE_ID' \
      'missing_coverage COVERAGE_MISSING_SOURCE' \
      'missing_acceptance_mapping COVERAGE_MISSING_ACCEPTANCE' \
      'acceptance_ownership ACCEPTANCE_OWNERSHIP_MISMATCH'; do
        defect="${pair%% *}"; code="${pair#* }"
        assert_output_repair "$defect" "$code"
    done
    jq -e 'any(.errors[]; .code=="STORY_SOURCE_REFS_MISMATCH" and .values.storyId=="TST-001" and (.values.omittedSourceIds|index("REQ-001")))' \
      "$TEST_TMP/repair-source_refs/.looper/test/decomposition/proposal-1-diagnostic-0.json" >/dev/null || fail "sourceRefs diagnostic omitted exact story/source IDs"
}

test_output_repair_dependencies() {
    assert_output_repair unknown_dependency DEPENDENCY_UNKNOWN
    assert_output_repair forward_dependency DEPENDENCY_NOT_EARLIER
}

test_output_repair_shape_and_optional_proof() {
    local repo="$TEST_TMP/invalid-proposal" bin="$TEST_TMP/invalid-proposal-bin"
    make_source_repo "$repo"; make_fake_codex "$bin"
    run_source_command "$repo" "$bin" FAKE_INVALID_DECOMPOSITION=1 "$SOURCE_DIR/bin/looper" prepare --spec request.md >/dev/null
    jq -e 'any(.errors[]; .code=="INVALID_SOURCE_KIND")' "$repo/.looper/test/decomposition/proposal-1-diagnostic-0.json" >/dev/null || fail "shape defect lacked a specific diagnostic"
    repo="$TEST_TMP/optional-proof"; bin="$TEST_TMP/optional-proof-bin"
    make_source_repo "$repo"; make_fake_codex "$bin"
    run_source_command "$repo" "$bin" FAKE_OPTIONAL_PROOF=1 "$SOURCE_DIR/bin/looper" prepare --spec request.md >/dev/null
    jq -e '.stories[0].proofExpectations[0] | has("command")|not' "$repo/.looper/test/stories.json" >/dev/null || fail "optional proof command was not accepted"
    assert_output_repair invalid_json INVALID_JSON
    assert_output_repair source_hash SOURCE_HASH_MISMATCH
    jq -e --arg expected "$(sha256sum "$TEST_TMP/repair-source_hash/.looper/test/source.md" | awk '{print $1}')" \
      'any(.errors[]; .code=="SOURCE_HASH_MISMATCH" and .values.expected==$expected and .values.received!=.values.expected)' \
      "$TEST_TMP/repair-source_hash/.looper/test/decomposition/proposal-1-diagnostic-0.json" >/dev/null || fail "source identity failure lacked immutable-source diagnostics"
}

test_output_repair_limit() {
    local repo="$TEST_TMP/repair-limit" bin="$TEST_TMP/repair-limit-bin" output="$TEST_TMP/repair-limit.out"
    make_source_repo "$repo"; make_fake_codex "$bin"
    if run_source_command "$repo" "$bin" FAKE_DECOMPOSITION_DEFECT=terminal_reason FAKE_DECOMPOSITION_DEFECT_ALWAYS=1 \
      LOOPER_DECOMPOSITION_OUTPUT_REPAIR_MAX_ATTEMPTS=2 "$SOURCE_DIR/bin/looper" prepare --spec request.md >"$output" 2>&1; then
        fail "exhausted output repairs unexpectedly succeeded"
    fi
    [ "$(jq -r '.status' "$repo/.looper/test/decomposition/state.json")" = DECOMPOSITION_OUTPUT_INVALID ] || fail "repair exhaustion was mislabeled as a human stop"
    [ "$(jq -r '.repairAttempt' "$repo/.looper/test/decomposition/state.json")" = 2 ] || fail "repair limit attempt was not persisted"
    [ "$(grep -c '^codex-decomposition-schema.json$' "$repo/.looper/test/stories/calls.log")" -eq 3 ] || fail "repair limit did not allow initial output plus two repairs"
    if grep -q '^codex-decomposition-review-schema.json$' "$repo/.looper/test/stories/calls.log"; then fail "invalid output reached adversarial review"; fi
    [ ! -f "$repo/.looper/test/stories.json" ] || fail "invalid output was published"
    grep -q 'Decomposer output remained invalid after 2 same-round repair attempts' "$output" || fail "repair exhaustion lacked a clear operator message"
    grep -q 'proposal-1-diagnostic-2.json' "$output" || fail "repair exhaustion did not identify its final diagnostic"
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

test_output_repair_resume() {
    local repo="$TEST_TMP/repair-resume" bin="$TEST_TMP/repair-resume-bin" pid child state=""
    make_source_repo "$repo"; make_fake_codex "$bin"
    (
      cd "$repo"
      exec env PATH="$bin:$PATH" FAKE_PROJECT_DIR="$repo" LOOPER_IMPLEMENTATION_AGENT=codex LOOPER_REVIEW_AGENT=codex \
        LOOPER_CODEX_BIN="$bin/codex" LOOPER_HEARTBEAT_INTERVAL=1 FAKE_DECOMPOSITION_DEFECT=terminal_reason FAKE_REPAIR_SLEEP=10 \
        "$SOURCE_DIR/bin/looper" prepare --spec request.md
    ) >/dev/null 2>&1 &
    pid=$!
    for _ in $(seq 1 100); do
        if [ -f "$repo/.looper/test/decomposition/state.json" ]; then
            state="$(jq -r '.status // empty' "$repo/.looper/test/decomposition/state.json" 2>/dev/null || true)"
            [ "$state" = OUTPUT_REPAIR_REQUIRED ] && break
        fi
        sleep 0.05
    done
    [ "$state" = OUTPUT_REPAIR_REQUIRED ] || { kill "$pid" >/dev/null 2>&1 || true; fail "repair run did not reach a resumable boundary"; }
    child="$(pgrep -P "$pid" 2>/dev/null || true)"
    kill -TERM "$pid" >/dev/null 2>&1 || true
    for child in $child; do
        pkill -TERM -P "$child" >/dev/null 2>&1 || true
        kill -TERM "$child" >/dev/null 2>&1 || true
    done
    wait "$pid" 2>/dev/null || true
    run_source_command "$repo" "$bin" FAKE_DECOMPOSITION_DEFECT=terminal_reason "$SOURCE_DIR/bin/looper" prepare --spec request.md >/dev/null
    [ "$(jq -r '.status' "$repo/.looper/test/decomposition/state.json")" = APPROVED ] || fail "interrupted output repair did not resume"
    [ "$(jq -r '.repairAttempt' "$repo/.looper/test/decomposition/state.json")" = 1 ] || fail "resume consumed a new repair attempt"
    [ "$(grep -c '^codex-decomposition-review-schema.json$' "$repo/.looper/test/stories/calls.log")" -eq 1 ] || fail "resumed correction was not reviewed exactly once"
}

test_decomposer_repository_boundary_and_timeout() {
    local repo="$TEST_TMP/decomposer-timeout" bin="$TEST_TMP/decomposer-timeout-bin" started elapsed
    make_source_repo "$repo"; make_fake_codex "$bin"
    started="$(date +%s)"
    if run_source_command "$repo" "$bin" FAKE_BROAD_SCAN=1 FAKE_BROAD_SCAN_SLEEP=10 \
      LOOPER_DECOMPOSITION_AGENT_TIMEOUT_SECONDS=1 LOOPER_DECOMPOSITION_OUTPUT_REPAIR_MAX_ATTEMPTS=1 \
      "$SOURCE_DIR/bin/looper" prepare --spec request.md >/dev/null 2>&1; then
        fail "timed-out broad scan unexpectedly succeeded"
    fi
    elapsed=$(( $(date +%s) - started ))
    [ "$elapsed" -lt 8 ] || fail "decomposer timeout did not prevent a broad scan from wedging the run"
    [ "$(cat "$repo/.looper/test/stories/decomposer-pwd.txt")" = "$repo" ] || fail "decomposer did not start at the supplied repository root"
    [ "$(jq -r '.status' "$repo/.looper/test/decomposition/state.json")" = DECOMPOSITION_AGENT_FAILED ] || fail "exhausted timeouts were mislabeled as author-content defects"
    jq -e '.failureType=="AGENT_TIMEOUT" and .timedOut==true' "$(jq -r '.agentFailureFile' "$repo/.looper/test/decomposition/state.json")" >/dev/null || fail "timeout failure diagnostic was not persisted"
    grep -Eq 'Never traverse parent directories|find /' "$SOURCE_DIR/templates/prompt.decomposer.md" || fail "decomposer prompt lacks repository traversal guardrails"
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

should_run_test() {
    local name="$1"
    [ -z "${LOOPER_TEST_FILTER:-}" ] || [[ ",${LOOPER_TEST_FILTER}," == *",${name},"* ]]
}

run_named_test() {
    local name="$1" function_name="$2"
    shift 2
    should_run_test "$name" || return 0
    [ "${LOOPER_TEST_TRACE:-0}" != "1" ] || echo "TEST $name" >&2
    "$function_name" "$@"
}

run_named_test happy_path test_happy_path
run_named_test plan_review_crash_resume test_plan_review_crash_resume
run_named_test commit_failure_resume test_commit_failure_resume
run_named_test planning_side_effect_guard test_planning_side_effect_guard
run_named_test plan_revision_before_implementation test_plan_revision_before_implementation
run_named_test active_lock_beats_reordered_stories test_active_lock_beats_reordered_stories
run_named_test missing_ac_proof_rejected test_missing_ac_proof_rejected
run_named_test terminal_split_required test_terminal_planning_disposition SPLIT_REQUIRED
run_named_test terminal_blocked test_terminal_planning_disposition BLOCKED
run_named_test terminal_recovery_story_hashes test_terminal_recovery_story_hashes
run_named_test prepare_source_kinds test_prepare_source_kinds
run_named_test decomposition_revision test_decomposition_revision
run_named_test decomposition_needs_human test_decomposition_needs_human
run_named_test reviewer_needs_human_and_review_limit test_reviewer_needs_human_and_review_limit
run_named_test reviewer_output_repair_matrix test_reviewer_output_repair_matrix
run_named_test reviewer_terminal_reason_repair_context test_reviewer_terminal_reason_repair_context
run_named_test reviewer_repair_limit_and_resume test_reviewer_repair_limit_and_resume
run_named_test reviewer_timeout_and_transport_failures test_reviewer_timeout_and_transport_failures
run_named_test runtime_pinning_and_tamper test_runtime_pinning_and_tamper
run_named_test repair_prompt_preserves_review_context test_repair_prompt_preserves_review_context
run_named_test delta_revision_validation_and_apply test_delta_revision_validation_and_apply
run_named_test agent_api_and_empty_output_failures test_agent_api_and_empty_output_failures
run_named_test timeout_retry_preserves_review_context test_timeout_retry_preserves_review_context
run_named_test correctable_review_limit_resume test_correctable_review_limit_resume
run_named_test repair_diagnostic_provenance test_repair_diagnostic_provenance
run_named_test output_repair_disposition_fields test_output_repair_disposition_fields
run_named_test output_repair_references_and_ids test_output_repair_references_and_ids
run_named_test output_repair_dependencies test_output_repair_dependencies
run_named_test output_repair_shape_and_optional_proof test_output_repair_shape_and_optional_proof
run_named_test output_repair_limit test_output_repair_limit
run_named_test output_repair_resume test_output_repair_resume
run_named_test decomposer_repository_boundary_and_timeout test_decomposer_repository_boundary_and_timeout
run_named_test approval_artifact_integrity test_approval_artifact_integrity
run_named_test changed_content_and_same_path test_changed_content_and_same_path
run_named_test source_idempotency_and_tamper test_source_idempotency_and_tamper
run_named_test start_converges_on_run_engine test_start_converges_on_run_engine
run_named_test cli_errors test_cli_errors
echo "integration tests passed"
