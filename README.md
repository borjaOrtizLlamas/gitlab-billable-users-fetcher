You can give me  your star if you like it :) 

# 🧾 GitLab Billable Users Exporter

A simple yet powerful **Bash script** that collects all **GitLab billable users** (across all groups) and exports them into a single **JSON report**.  
This tool automates what GitLab’s API and CLI currently cannot do directly — fetching all **billable users** without manually looping through each group.


---

## 🚀 Why this script?

GitLab does not provide a CLI command or API endpoint to list **all billable users** in a single request.  
You must query each group’s `billable_members` API separately — which is tedious, slow, and error-prone.

This script:
- Iterates over **all groups** (optionally only top-level).
- Fetches **billable members** via the GitLab REST API.
- Normalizes and merges all users into a **single JSON file**.
- Skips duplicates automatically.

Perfect for:
- **Auditing GitLab billing usage**
- **Exporting user data** for analysis
- **Compliance or cost management**

---

## 🧠 Features

- ✅ Fetches all GitLab **billable users** automatically  
- ✅ Works for both **GitLab.com** and **self-managed** instances  
- ✅ Outputs clean **JSON** data ready for processing  
- ✅ Handles **pagination**, **duplicates**, and **date filtering**  
- ✅ Uses only standard tools: `bash`, `curl`, and `jq`  

---

## ⚙️ Environment Variables

| Variable | Default | Description |
|-----------|----------|-------------|
| `GITLAB_HOST` | `https://gitlab.com` | Your GitLab instance URL |
| `TOKEN` | `your-token` | Personal Access Token with API access |
| `TOP_LEVEL_ONLY` | `true` | Whether to fetch only top-level groups |
| `SINCE` | `2000-09-03T00:00:00Z` | Filter users created after this date |
| `OUT_JSON` | `all_billable_users.json` | Output file path |

---

## 🧩 Example Usage

```bash
# Make the script executable
chmod +x get-gitlab-billable-users.sh

# Run it with your GitLab token
GITLAB_HOST="internal.git.com" TOKEN="glpat-xxxxxxxxxxxxxxxxxx" ./get-gitlab-billable-users.sh
