# Planning Changes

## Executing Plans

When executing plans, build a temporary plan first.
Write the temporary plan to the `.agent/agent-memory` directory.
When the user approves the write or replace for the temporary plan, start executing it iteratively; no need to ask before starting.

Temporary plans should include detailed information and have checkboxes to track progress over many interactive sessions.
Temporary plans act like a plan progress state, so if an agent fails midway through, we can pick up where we left off.
A "temporary plan" is different than a normal plan. It doesn't follow the same rules for creation or field generation.

Plan execution automatic cut-off:
Before executing an operation, agents must check their context.
If context % is greater than 40% or if they have greater than 50000 tokens they need to stop.
Agents should then update the temporary plan with progress and inform the user that the context is getting large.

## Creating Plans

This refers to "Plans" not "Temporary plans" which follow different guidelines.
When asked to accomplish broad goals, such as "investigate the codebase and update the code to meet our standards" or when asked to add major features, such as "add agentic framework to this repo", create a plan.
As a guideline, when modifying 5 or more files or modifying 300 lines of code, ask if we should make a plan.
Plans should include detailed instructions including goals and code snippets.
Plans should include an "Executed Date" (use "pending" for temporary/ongoing plans) and a "Purpose" field.
The "Purpose" field should give a high-level abstract of the plan.
An agent should be able to read all of the "Purpose" fields of plans in `.agent/plans/` to get a good understanding of major changes and historical context in the codebase.
 
