# General Rules

- Always confirm with the user before making any changes to the code or documentation.

# Documentation

## Overview

There are four types of documentation:
- Product Vision Document which defines the long-term vision for the product including features that have not yet been built
- Product documentation which documents the current product without overlapping with individual module documentation
- Module documentation which represents the current state of the module
- Tickets which represent a change that is proposed to be made

## Product Vision Document

The product vision document is stored in the root directory as `Vision.md` and defines the long-term vision for the product including features that have not yet been built.

The product vision document should contain:
- Long-term strategic goals and objectives
- Future features and capabilities planned for the product
- Product roadmap and timeline considerations
- High-level architectural visions for future development

## Product Documentation

Product documentation documents the current state of the entire product without overlapping with the details given in individual module documentation. The product documentation file is stored at the root of the project and is named with the title from product.yaml suffixed with ".md" for markdown.

For example, if product.yaml contains `title: Product Title`, the product documentation file would be named `Product Title.md`.

Product documentation should contain:
- High-level overview of the product's current capabilities and features
- Integration points between different modules
- User-facing functionality and workflows
- Product architecture and data flow overview
- System-level configuration and deployment information
- Cross-cutting concerns like security, performance, and monitoring

Product documentation should avoid:
- Detailed implementation specifics of individual modules
- Code-level documentation or API details that belong in module documentation
- Future planning information that belongs in the Product Vision Document

### Referencing Current vs Future State

For understanding the **current state** of the product, refer to:
- Product documentation (\<product-title\>.md) - Current product overview and capabilities
- Module documentation - Current implementation state of each module

For understanding the **future state** of the product, refer to:
- Product Vision Document (Vision.md) - Long-term strategic vision and planned features
- Tickets - Specific planned changes and implementation details

## Module Documentation

Module documentation is represented by a single Markdown file called \<module-title\>.md (where \<module-title\> is the title defined in the module.yaml file located in the module directory) located in the root directory of the module directory.

Module documentation should strictly represent the current state of the module and should never include any discussion of future enhancements because these should all be captured by tickets and the product vision document.  Sections such as the following should never be part of a module document:
- Current Implementation Status
- Completed Features
- In Development
- Future Development

## Roadmap

The Roadmap document is stored at `Project/Roadmap.md` and defines the linear execution order for tickets. Tickets must be executed in the order defined in this document. If the order needs to change, the Roadmap must be updated first before executing tickets out of sequence.

The Roadmap contains three sections:
- **Planned** — Tickets that have been prioritised and are in order ready to execute. Work through these top-to-bottom.
- **Not Planned** — Tickets that have been created but not formally prioritised for execution.
- **Complete** — Tickets that have been completed, listed in the order they were finished.

When picking up the next ticket to work on, always consult the Roadmap to determine which ticket is next in the Planned section.

## Tickets

Tickets are stored in the tickets directory at the root of the main repository `./_tickets/`

Tickets are created from the template file
./_templates/Ticket.md and contain the following YAML front matter:

```yaml
template: "[[Ticket]]"
kind: ticket
tags:
  - ticket
code: 
aliases:
name: 
ticket_status: 
```

Explanation of the YAML keys:
- `template`: Always set to "[[Ticket]]" to indicate the type of the file.
- `kind`: Always set to "ticket" to indicate the type of the file.
- `tags`: Always contains the tag "ticket" to indicate the type of the file.
- `code`: A unique code for the ticket which is also used at the beginning of the filename.
- `aliases`: Obsidian aliases for the ticket, typically the same as the `code`.
- `name`: A human-readable name for the ticket.
- `ticket_status`: The status of the ticket.

Valid values for `ticket_status` are:
- `[[Backlog]]`: The ticket is in the backlog and not yet started.
- `[[Ready]]`: The ticket is ready to be worked on.
- `[[In Progress]]`: The ticket is currently being worked on.
- `[[Done]]`: The ticket has been completed.
- '[[Wont Fix]]': The ticket will not be worked on.  This can be interpreted as a vote against the change defined by the ticket.
- '[[Duplicate]]': The ticket is a duplicate of another ticket.  This should not be interpreted as a vote against the change defined by the ticket.

# Ticket Execution

You should only work on tickets that are in the `[[Ready]]` or `[[In Progress]]` status.  If the user asks you to work on a ticket that is in the `[[Backlog]]` status, you should ask them to change the status to `[[Ready]]` first.

When creating a new ticket, use the template file and fill in the required fields.  The `code` field should be unique and follow the format `SIQ001`, `SIQ002`, etc.  The `name` field should be a descriptive name for the ticket.  The `ticket_status` should be set to `[[Backlog]]` by default.

When picking up a new ticket, the first thing to do is to plan out the execution as a linear series of tasks.  This should be done in the `# Execution Plan` section of the ticket.  The execution plan should be a list of tasks that need to be completed to finish the ticket.  Each task should be a single line and should be written in the imperative mood, e.g. "Implement the API endpoint", "Write unit tests", etc.  Tasks should use the Markdown task list format, e.g. `- [ ] Task description`.

After writing the Execution Plan, always stop and ask the user if they want to proceed with the plan.  If they agree, you can start executing the tasks one by one.  If they ask for changes to the plan, update the plan accordingly and ask for confirmation again.

When executing in agent mode, do tasks one by one.

The first thing to do when starting on a task is to confirm that the spec is complete and correct.  Work with the user to update the spec documented in the ticket before proceeding to make changes.

After each tasks is completed, mark the task as done in the `# Execution Plan` section by changing the `- [ ]` to `- [x]`.  If you need to ask the user a question, do so before marking the task as done.  If you need to wait for a response from the user, pause the execution until you receive a response.

After each tasks is completed, also update the documentation file for the affected services.  Refer to the table above for the services and their documentation files.  The documentation file should be updated with the changes made in the ticket.  If the ticket affects multiple services, update all relevant documentation files.

After a ticket is fully completed, move it from the Planned section to the Complete section in `Project/Roadmap.md`.  Append it to the bottom of the Complete list (maintaining chronological completion order).

