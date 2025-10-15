#!/usr/bin/env bash
set -euo pipefail

: "${GITLAB_HOST:=https://gitlab.com}"          
: "${TOKEN:="your-token"}"

: "${TOP_LEVEL_ONLY:=true}"   

# Example: "2025-09-23T00:00:00Z"
: "${SINCE:="2000-09-03T00:00:00Z"}"

: "${OUT_JSON:=all_billable_users.json}"


#-----------------------------------------------------------
# Perform an authenticated API call to the GitLab REST API.
#--------------------------------------------
api() {
  local path="$1"
  echo "----- $GITLAB_HOST/api/v4/$path" >&2

  curl -sS --fail -H "PRIVATE-TOKEN: $TOKEN" "$GITLAB_HOST/api/v4/$path"
}

#-----------------------------------------------------------
# Fetch all paginated results from a GitLab API endpoint.
# Iterates through all pages (per_page=100) and merges them.
#-----------------------------------------------------------
fetch_all_pages() {
  local base_path="$1"
  local page=1
  local all='[]'

  echo "Fetching data..." >&2

  while :; do
    local sep='?'
    [[ "$base_path" == *\?* ]] && sep='&'
    local url="${base_path}${sep}per_page=100&page=${page}"

    local chunk
    if ! chunk="$(api "$url")"; then
      echo "API call failed for $url" >&2
      break
    fi

    if [ -z "$chunk" ] || ! echo "$chunk" | jq -e . >/dev/null 2>&1; then
      echo "Empty or invalid JSON response on page $page" >&2
      break
    fi

    if [ "$(echo "$chunk" | jq 'length')" -eq 0 ]; then
      break
    fi

    all="$(jq -s 'add' <(echo "$all") <(echo "$chunk"))"
    page=$((page+1))
  done

  echo "$all"
}

#-----------------------------------------------------------
# Build the query string for fetching GitLab groups.
# If TOP_LEVEL_ONLY=true, only top-level groups are listed.
#-----------------------------------------------------------
build_groups_query() {
  local q="groups?"
  if [ "${TOP_LEVEL_ONLY}" = "true" ]; then
    q+="top_level_only=true&"
  fi
  echo "${q%&}"
}

#-----------------------------------------------------------
# Add a user entry to the output JSON file if not already present.
# Uses user_id as the unique key.
#-----------------------------------------------------------
add_user_if_missing() {
  local user_json="$1"
  local uid
  uid="$(echo "$user_json" | jq -r '.user_id|tostring')"

  if [ ! -f "$OUT_JSON" ]; then
    echo "[]" > "$OUT_JSON"
  fi

  if jq -e --arg uid "$uid" 'map(.user_id|tostring) | index($uid)' "$OUT_JSON" >/dev/null; then
    return 0
  fi

  local tmp
  tmp="$(mktemp)"
  jq --argjson u "$user_json" '. + [$u]' "$OUT_JSON" > "$tmp" && mv "$tmp" "$OUT_JSON"
}

if [ ! -f "$OUT_JSON" ]; then
  echo "[]" > "$OUT_JSON"
fi

echo "Listing groups..." >&2
GROUPS_QUERY="$(build_groups_query)"
GROUPS_JSON="$(fetch_all_pages "${GROUPS_QUERY}")"
TOTAL_GROUPS="$(echo "$GROUPS_JSON" | jq 'length')"
echo "Groups found: ${TOTAL_GROUPS}" >&2

#-----------------------------------------------------------
# Main execution flow:
# 1. Fetch all groups.
# 2. For each group, get its billable members.
# 3. Normalize and merge results into a single JSON file.
#-----------------------------------------------------------
if [ "$TOTAL_GROUPS" -eq 0 ]; then
  echo "No groups to process with current filters." >&2
  exit 0
fi

i=0
echo "$GROUPS_JSON" | jq -r '.[] | @base64' | while read -r row; do
  _jq() { echo "$row" | base64 --decode | jq -r "$1"; }
  GID="$(_jq '.id')"
  GPATH="$(_jq '.full_path')"
  GNAME="$(_jq '.name')"
  i=$((i+1))
  echo "(${i}/${TOTAL_GROUPS}) Group: ${GNAME} (${GPATH}) [id=${GID}] → billable_members..." >&2

  MEMBERS="$(fetch_all_pages "groups/${GID}/billable_members?")"

  MAPPED="$(jq -n --arg SINCE "$SINCE" --arg gid "$GID" --arg gpath "$GPATH" '
     | inputs
  ' <<<"$MEMBERS" 2>/dev/null || true)"

  if [ -z "$MAPPED" ]; then
    MAPPED="$(echo "$MEMBERS" | jq --arg SINCE "$SINCE" '
      map({
        user_id: (.id // .user_id // .user?.id),
        username: (.username // .user?.username),
        name: (.name // .user?.name),
        public_email: (.public_email // .user?.public_email // ""),
        email: (.email // .user?.email // ""),
        state: (.state // .user?.state // ""),
        locked: (.locked // .user?.locked // false),
        avatar_url: (.avatar_url // .user?.avatar_url // ""),
        web_url: (.web_url // .user?.web_url // ""),
        last_activity_on: (.last_activity_on // .user?.last_activity_on // ""),
        membership_type: (.membership_type // .user?.membership_type // ""),
        removable: (.removable // .user?.removable // false),
        created_at: (.created_at // .user?.created_at // ""),
        is_last_owner: (.is_last_owner // .user?.is_last_owner // false),
        last_login_at: (.last_login_at // .user?.last_login_at // "")
      })
      | map(select(.user_id != null))
      | (if ($SINCE|length) > 0
        then map(select(.created_at != null and .created_at >= $SINCE))
        else .
        end)
    ')"
fi
  echo "$MAPPED" | jq -c '.[]' | while read -r u; do
    add_user_if_missing "$u"
  done
done

COUNT="$(jq 'length' "$OUT_JSON")"
echo "Done. Total users in ${OUT_JSON}: ${COUNT}" >&2
