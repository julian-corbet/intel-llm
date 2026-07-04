# intel-llm

Fast local LLMs on Intel laptops — **install one thing, be done.** No compilation.

```
paru -S intel-llm
intel-llm gpu -hf ggml-org/Qwen2.5-1.5B-Instruct-Q4_K_M-GGUF   # Arc GPU (SYCL)
intel-llm npu OpenVINO/Qwen2.5-1.5B-Instruct-int4-ov -p "Hi"   # NPU  (OpenVINO GenAI)
intel-llm devices                                              # what's usable
```

## Why

Intel Arc + NPU laptops have no turnkey llama.cpp on Arch: the SYCL path means
compiling from source, and llama.cpp's own OpenVINO/NPU backend is ~190× too slow
to use. This ships **official precompiled binaries** for both fast paths and wires
them behind one command.

| Path | Engine | Device | Speed (1.5B, Lunar Lake) |
|------|--------|--------|--------------------------|
| GPU  | llama.cpp SYCL fp16 | Intel Arc | ~25 tok/s |
| NPU  | OpenVINO GenAI (INT4 IR) | Intel AI Boost | ~17 tok/s |

The two engines are independent packages; `intel-llm` is a thin meta + launchers.

## Packages

| Package | What | Source |
|---------|------|--------|
| `llama.cpp-sycl-bin` | Arc GPU engine | upstream llama.cpp release (`ubuntu-sycl-fp16`), MIT |
| `openvino-genai-bin` | NPU/GPU/CPU engine (Python 3.14) | official OpenVINO GenAI wheels, Apache-2.0 |
| `intel-llm` | `intel-llm` / `intel-gpu` / `intel-npu` launchers | this repo, MIT |
| `intel-llm-convert` *(optional)* | convert your own HF models → NPU INT4 IR | optimum-intel + nncf |

Nothing proprietary is redistributed: binaries are downloaded from upstream's
official releases at build time; Intel oneAPI (for the GPU path) is an optional
dependency the user installs.

## Requirements

- **GPU path:** `intel-oneapi-basekit` (SYCL runtime), an Intel Arc GPU.
- **NPU path:** `intel-npu-driver`, and your user in the `render` group
  (`sudo usermod -aG render "$USER"`, then re-login).

## Updating

The AUR packages are bumped automatically (daily) by CI when upstream releases a
new llama.cpp / OpenVINO GenAI, so a normal system upgrade keeps you current.
