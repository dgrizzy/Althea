from __future__ import annotations

from app.clients.github_issues import GitHubIssuesClient, NullGitHubIssuesClient

GitHubStatusClient = GitHubIssuesClient | NullGitHubIssuesClient
