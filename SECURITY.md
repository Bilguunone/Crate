# Security Policy

## Supported Versions

Crate is pre-1.0. Security fixes should target the current main branch.

## Reporting A Vulnerability

Please do not open a public issue for vulnerabilities involving arbitrary file access, unsafe imports, path traversal, or packaged-app signing behavior.

Report privately to the maintainer by email or direct message if a private contact is listed on the repository profile. If no private channel is available yet, open a minimal issue that says you have a security report without including exploit details.

## Local Files

Crate is intentionally local-first and works with user-selected folders. Bugs around path handling, deletion, import cleanup, export behavior, and library migration should be treated carefully because they can affect user files.
