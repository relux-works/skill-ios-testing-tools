# AGENTS.md

## Project-Neutral Toolkit Rule

This repository is a reusable iOS testing toolkit. Keep toolkit-owned source, tests, specs, diagrams, samples, skill docs, scripts, and generated architecture artifacts maximally project-neutral.

Do not add product-project-specific names, bundle identifiers, device names, domain events, user flows, business entities, backend assumptions, or legacy harness details to toolkit-owned artifacts.

Treat every toolkit-owned implementation, sample, diagram, spec, and instruction as generalized infrastructure first. Product repositories may use the toolkit as validation targets, but their domain language, workflows, test personas, transport assumptions, fixtures, device names, app identifiers, backend contracts, and migration details must never become toolkit defaults, sample names, public API names, or architectural examples.

If a reusable feature cannot be described without mentioning a concrete consumer project, stop and split the work: keep the generic mechanism in this repository and move the consumer-specific scenario, mapping, or validation note into that product repository.

Use neutral placeholders and roles:

- `Consumer iOS project`
- `AppUnderTest`
- `ProductUITests`
- `peer alpha`
- `peer beta`
- `observer`
- `project-specific event`
- `synchronized action`

Project-specific behavior belongs only in the consumer project:

- consumer config files
- consumer UI test scenario code
- consumer task-board outcomes
- consumer validation notes
- consumer migration documentation

When validating this toolkit against a real product project, record product-specific findings in that product repository or in clearly scoped consumer-validation board tasks. Do not copy those semantics back into toolkit core, toolkit samples, generalized specs, or architecture diagrams.
