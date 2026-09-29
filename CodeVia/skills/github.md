---
schemaVersion: 2
id: "skill-github"
slug: "github"
name: "GitHub"
description: "GitHub repo, branch, commit, PR, issue, and webhook operations."
category: "devops"
version: "1.0.0"
tools: ["github","git"]
dependencies: ["git"]
compatibleAgentTypes: ["devops","release","code-reviewer","backend-developer"]
metadata: {}
enabled: true
builtIn: true
createdAt: "2026-09-04T17:54:22.435Z"
updatedAt: "2026-09-04T17:54:22.435Z"
---

Use GitHub as the source of truth. Keep secrets out of the repo; reference them via secretRef.