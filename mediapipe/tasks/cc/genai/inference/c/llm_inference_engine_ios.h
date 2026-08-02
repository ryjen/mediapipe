// Copyright 2024 The MediaPipe Authors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#ifndef MEDIAPIPE_TASKS_GENAI_INFERENCE_C_LLM_INFERENCE_ENGINE_IOS_H_
#define MEDIAPIPE_TASKS_GENAI_INFERENCE_C_LLM_INFERENCE_ENGINE_IOS_H_

#include <CoreGraphics/CoreGraphics.h>

// The public v0.10.26 source distribution references an iOS-specific header
// that is not included in the tag. This compatibility header preserves the
// exported XCFramework API while the custom distribution uses the available
// CPU implementation. CGImage input remains unsupported by that backend.
#include "mediapipe/tasks/cc/genai/inference/c/llm_inference_engine.h"

#ifdef __cplusplus
extern "C" {
#endif

// Adds a CGImage to the session. The public CPU-only implementation returns
// kUnimplemented because the iOS multimodal backend is not published.
ODML_EXPORT int LlmInferenceEngine_Session_AddCgImage(
    LlmInferenceEngine_Session* session, CGImageRef image, char** error_msg);

#ifdef __cplusplus
}  // extern "C"
#endif

#endif  // MEDIAPIPE_TASKS_GENAI_INFERENCE_C_LLM_INFERENCE_ENGINE_IOS_H_
