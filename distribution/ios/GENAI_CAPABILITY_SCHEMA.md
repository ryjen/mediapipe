# GenAI capability schema v1

This file reserves the schema identifier used by the packaged `EyespieMediaPipeGenAICapabilities.json` manifest.

The authoritative consumer-facing contract is documented in `GENAI_CAPABILITIES.md`. Schema version `1` requires:

- distribution identity and exact source revisions;
- minimum iOS and architecture matrix;
- backend identifier;
- explicit GPU-acceleration support;
- text-generation API availability and qualified model-family list;
- `CGImage` support and stable error behavior;
- upstream issue references.

Schema changes that alter field meaning or remove required fields must increment `schema_version`. Additive fields may retain the current version when older consumers can safely ignore them.
