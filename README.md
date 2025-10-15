# gitlab-billable-users-fetcher

GitLab doesn’t provide a built-in CLI command or API endpoint to list all billable users at once — you have to fetch them group by group.

This script automates that process: it iterates through all your GitLab groups, retrieves their billable members via the API, and merges them into a single JSON file.

Perfect for audits, billing checks, or user management automation.
