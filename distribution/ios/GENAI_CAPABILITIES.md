# Eyespie iOS GenAI capability contract

The `EyespieMediaPipeTasksGenAI` distribution is built from the public MediaPipe `v0.10.26` source line. That source references an iOS-specific GenAI implementation which is not published upstream, so this distribution deliberately uses the available CPU implementation instead of claiming parity with Google's complete binary distribution.

## Supported boundary

| Capability | Status |
|---|---|
| Text-generation API | Available through the public CPU implementation |
| Qualified model families | None yet; device qualification is tracked separately |
| GPU acceleration | Unsupported and not claimed |
| `CGImage` input | Unsupported; returns `kUnimplemented` |
| Minimum iOS | 15.0 |
| Device architecture | arm64 |
| Simulator architectures | arm64, x86_64 |

API availability is not a production-performance claim. Physical-device latency, memory, thermal, and energy qualification is tracked in `ryjen/mediapipe#3`.

## Runtime API

`MediaPipeTasksGenAIC` exports the following namespaced C functions through `llm_inference_engine_ios.h`:

```c
int EyespieMediaPipeGenAI_CapabilitySchemaVersion(void);
const char* EyespieMediaPipeGenAI_Backend(void);
int EyespieMediaPipeGenAI_SupportsTextGeneration(void);
int EyespieMediaPipeGenAI_SupportsCgImageInput(void);
int EyespieMediaPipeGenAI_SupportsGpuAcceleration(void);
```

Current values are:

- schema version: `1`
- backend: `public_cpu_only`
- text-generation API: `1`
- `CGImage` input: `0`
- GPU acceleration: `0`

Consumers should use these values to gate platform features instead of inferring capability from module availability or successful linkage.

## Packaged manifest

The GenAI archive contains:

```text
capabilities/EyespieMediaPipeGenAICapabilities.json
```

The podspec packages it into the resource bundle:

```text
EyespieMediaPipeTasksGenAICapabilities.bundle
```

The manifest records the schema version, distribution and upstream revisions, platform architecture matrix, backend identity, supported feature boundary, qualification state, and relevant upstream issues.

The manifest and exported C API are validated during artifact construction. The build fails if the metadata disagrees with the expected CPU-only contract or if any capability symbol is missing from an XCFramework slice.

## Error contract

`LlmInferenceEngine_Session_AddCgImage`:

- returns `absl::StatusCode::kUnimplemented`;
- provides an actionable error string when an error output pointer is supplied;
- performs no partial feature initialization or state mutation;
- must not be interpreted as a GPU or multimodal fallback.

## Removal criteria

The compatibility contract may be replaced only when upstream provides a complete, buildable iOS implementation and the replacement passes:

1. ABI and behavioral comparison against this contract;
2. simulator arm64 and x86_64 linkage;
3. physical-device arm64 validation;
4. Eyespie static KMP integration;
5. explicit migration tests for capability gating.

Relevant upstream reports:

- `google-ai-edge/mediapipe#6234` — missing public iOS GenAI implementation sources
- `google-ai-edge/mediapipe#6246` — iOS GenAI/Skia symbol collision risk
