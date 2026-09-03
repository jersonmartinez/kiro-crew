# KiroCrew Documentation

English is the canonical documentation language. Spanish translations are maintained in parallel and should be updated in the same change when behavior, security, or operational guidance changes.

## Languages

- [English documentation](en/README.md)
- [Documentación en español](es/README.md)

## Topics

- [English security guide](en/security.md)
- [Guía de seguridad en español](es/security.md)
- [English architecture decision records](en/decisions/)
- [Registros de decisiones en español](es/decisions/)
- [Interactive architecture diagrams](architecture/)

## Documentation rules

- Keep product names, commands, paths, environment variables, service names, and technical identifiers unchanged across languages.
- Treat `docs/en/` as the canonical English source and `docs/es/` as its maintained translation.
- Do not include credentials, tokens, private paths, or environment-specific project names in documentation or generated artifacts.
- Record significant security and architecture decisions as sequential ADRs in both language trees.
- Generated browser evidence is intentionally ignored; keep the Archify source JSON and final HTML diagrams only.
