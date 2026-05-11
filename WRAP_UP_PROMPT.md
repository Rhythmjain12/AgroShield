# AgroShield — Standard Session Wrap-Up Prompt

Copy-paste this at the end of any session where code or docs changed.
Fill in [X] with the current chat number.

---

```
This session is complete. Please do the following:

1. COMMIT & PUSH all changed/new files to GitHub (main branch).
   Summarise changes in the commit message.

2. UPDATE these docs to reflect what was built/fixed:
   - Claude artifacts/agroshield_roadmap_v3.md — mark this chat done; set next as Current
   - Claude artifacts/agroshield_prd_v2.md — update Status line and any changed feature sections
   - Claude artifacts/agroshield_pm_portfolio_v3.md — update Artifacts Produced table
   - PROJECT_MASTER.md — update Last updated, Status, and Build Order table
   - Handoffs/HANDOFF_chat[X].md — generate/update handoff for this session

3. OUTPUT the handoff doc and the prompt to use at the start of the next session.
```
