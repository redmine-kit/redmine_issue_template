---
name: use-issue-templates
description: Create Redmine issues from the project's issue templates and their forms. Use when the project has templates for the kind of issue the user wants to file.
---

# Use issue templates

1. List the templates the user may use with `issue_template.list_templates` for the project, and pick the one that matches the request; ask when several fit.
2. Answer the template's form by each field's `ref`, with the choices the form gives. Ask the user for required answers you don't know.
3. Don't set values the template sets itself; the template decides them.
4. Create the issue with `issue_template.create_issue`, passing the template's key and the answers.
5. If the tool returns errors, fix the answers they name and try once more.
6. Tell the user the issue's number.
