# KDE Helper VS Code Extension

This extension provides a tree view for managing KDE environments and projects.

## Features

- List environments via `kde ls`.
- Inline actions for each environment:
  - Start: `kde start <env>`
  - Use: `kde use <env>` and mark as 使用中
  - K9s: `kde use <env> && kde k9s`
  - Headlamp: `kde use <env> && kde headlamp`
- Expand environments to show projects.
- Inline actions for each project:
  - Deploy: `kde use <env> && kde project deploy <project>`
  - Undeploy: `kde use <env> && kde project undeploy <project>`
  - Redeploy: `kde use <env> && kde project redeploy <project>`

Commands run inside an integrated terminal named **KDE**.

