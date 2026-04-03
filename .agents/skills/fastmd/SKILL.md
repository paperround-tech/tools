---
name: fastmd
description: >
  Use the FastMD MCP server to read, write, and manage markdown documents in shared workspaces.
  Use this skill when creating runbooks, storing investigation notes, writing documentation,
  or retrieving existing markdown content from a FastMD workspace.
---

# FastMD

## Bootstrap (Run at the start of every conversation)
Before responding to any task, search the FastMD KB workspace for documents relevant
to the topic at hand. Read any that look useful and use them to inform your response — treat
FastMD as a persistent knowledge base, not just a place to store things.

```
Tool: search_files
{ "query": "<topic keywords>", "workspace_id": "0c8dbcfe-d5a0-475e-bf13-22c1275d77fa" }
```

If the task touches multiple domains (e.g. a specific repo AND a DB operation), run multiple
searches. If nothing relevant is found, proceed without it.

FastMD is a collaborative markdown workspace available via MCP.

## MCP Server
- **Server name:** `fastmdv2`
- **Server ID:** `d75b8739-cdcc-45c4-b137-702c8b332470`

Always use `call_mcp_tool` with `server_id: d75b8739-cdcc-45c4-b137-702c8b332470`.

## Workspaces
| Name    | ID                                     | Role  | Notes              |
|---------|----------------------------------------|-------|-----------------|
| KB      | `0c8dbcfe-d5a0-475e-bf13-22c1275d77fa` | owner | **Primary KB — use this by default** |
| Sandbox | `e34f41ae-bf66-4cac-99c9-6cb48ea177de` | owner | Playground only, not part of the KB |

Use the KB workspace unless told otherwise.

## Common Operations

### List files in a workspace
```json
{ "workspace_id": "0c8dbcfe-d5a0-475e-bf13-22c1275d77fa" }
```
Tool: `list_files`

### Read a file
```json
{ "workspace_id": "0c8dbcfe-d5a0-475e-bf13-22c1275d77fa", "file_id": "<file_id>" }
```
Tool: `read_file`

### Create a file
```json
{ "workspace_id": "0c8dbcfe-d5a0-475e-bf13-22c1275d77fa", "path": "folder/filename.md", "content": "# Title\n..." }
```
Tool: `create_file`

### Update a file
```json
{ "workspace_id": "0c8dbcfe-d5a0-475e-bf13-22c1275d77fa", "file_id": "<file_id>", "content": "..." }
```
Tool: `update_file`

### Search across files
```json
{ "query": "search term", "workspace_id": "0c8dbcfe-d5a0-475e-bf13-22c1275d77fa" }
```
Tool: `search_files`

### Move / rename a file
```json
{ "workspace_id": "0c8dbcfe-d5a0-475e-bf13-22c1275d77fa", "file_id": "<file_id>", "new_path": "new/path.md" }
```
Tool: `move_file`

### Delete a file
```json
{ "workspace_id": "0c8dbcfe-d5a0-475e-bf13-22c1275d77fa", "file_id": "<file_id>" }
```
Tool: `delete_file`

## Save to KB Workflow
When the user says **"save this to the KB"** (or similar — "store this", "add this to the knowledge base"), distill the key knowledge from the current conversation and write it to FastMD.

### Steps
1. **Search first** — check whether a relevant file already exists (`search_files`). If it does, update it rather than creating a duplicate.
2. **Distill** — extract the durable knowledge: decisions made, how things work, commands/patterns discovered, gotchas. Strip out conversational back-and-forth.
3. **Choose a path** — pick a sensible path using the conventions below.
4. **Write** — create or update the file via `create_file` or `update_file`.
5. **Confirm** — tell the user the path the content was saved to.

### Path Conventions
| Folder | Content |
|---|---|
| `repos/` | Repo overviews, structure, setup instructions |
| `runbooks/` | Step-by-step operational procedures |
| `investigations/` | Debugging sessions, root cause analyses |
| `architecture/` | System design, data flows, service relationships |
| `workflows/` | Cross-system or cross-team processes |
| `oncall/` | Incident notes, on-call procedures |
| `people/` | Team structure, roles, contacts |

## Conventions
- All file paths must end in `.md`.
- Prefer updating existing files over creating duplicates — always search first.
- Write for future-you: assume no memory of the conversation. Include enough context to be useful standalone.
