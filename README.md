# Watch-Dino Visual HTML Editor

Standalone visual HTML editor for Watch-Dino design work. This repository is intentionally separate from `jfsd25-dc/Watch-Dino`.

The editor starts with **no HTML loaded**.

Sources:
- Local `.html` / `.htm` file
- GitHub repository + branch + selected HTML file

## Private GitHub repositories

Set this environment variable on the Vercel project:

```text
GITHUB_TOKEN=<GitHub fine-grained token with read-only Contents access>
```

The token is used only by `/api/github-files` and `/api/github-file`. It is never sent to browser JavaScript.

Recommended token scope:
- Repository access: only the Watch-Dino repository
- Repository permissions: Contents = Read-only
