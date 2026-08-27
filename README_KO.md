# AI 가속기와 스토리지의 데이터 이동 병목 분석 및 시스템 최적화

**권오영** · 숭실대학교 컴퓨터학부 (2027년 2월 졸업 예정)
· 지원 분야: SK하이닉스 **SYSTEM SW** — AI 메모리/스토리지 시스템 소프트웨어

> CPU·GPU·NPU·SSD에서 데이터가 **어떤 형식으로 저장되고 어떤 경로로 이동하는지**가
> 시스템 성능을 어떻게 제한하는지 측정하고, HW/SW 경계에서 병목을 검증하고
> 개선하는 시스템 아키텍처 엔지니어를 지향한다.

---

## 공통 질문

두 프로젝트는 같은 프로젝트가 아니다. 스택의 서로 다른 층에서 **같은 방법론**을
적용한 두 사례이며, 그 방법론이 핵심이다.

| | NPU (메인) | SSD (보조) |
|---|---|---|
| 이동하는 것 | LLM KV-cache: 양자화 payload + 그룹별 metadata | Host I/O: LBA write, GC page copy |
| 이동 경로 | dequant 엔진 → SRAM → HBM | host queue → FTL mapping → NAND channel |
| 병목 요인 | DRAM traffic, dequant 엔진 배분, mode-switch 비용 | queue wait, GC-induced stall, write amplification |
| 측정 지표 | cycle, DRAM traffic 구성비, 엔진 utilization | p99 latency, WAF, GC stall |
| 도구 | 계측 확장한 ONNXim (C++, cycle-level) | 직접 작성한 FTL/NAND 시뮬레이터 (C++17) |

**저장 형식과 이동 경로가 병목을 어떻게 만들고, 그것을 어떤 계측으로 증명하는가.**

---

## 프로젝트

### 1. NPU KV Asymmetry — 계측 확장한 ONNXim
[projects/npu-kv-architecture.md](projects/npu-kv-architecture.md) ·
저장소: **private — 요청 시 공유** · 재현 상태: **검증 완료**
(shared 기준선 33,267,145 cycles · split 85:43 33,501,237 cycles, +0.70 %)

양자화 LLM에서 K와 V의 dequant 자원 수요 차이가 **dequant 엔진 분할**을 정당화하는지
물었다. ONNXim에 dequant 비용 모델·K/V 분리 카운터·provenance 로깅을 추가하고
배분비를 스윕한 결과, **내 제안을 스스로 기각**했다 — 정확히 맞춘 분할조차 공유 대비
0.7~1.2 % 안쪽이라 하드웨어 값을 못 한다. 대신 찾고 있지 않던 것이 나왔다:
**측정된** FP16·batch 16 분해에 bit-width·batch scaling law를 적용하면, INT4·batch 64에서
KV metadata가 모델링된 트래픽의 **26.3 %**, weight가 **21.3 %**를 차지할 것으로 예측된다 —
payload가 아니라 양자화 장부가 다음 병목 후보일 수 있다. **다만 INT4·batch 64 조건 자체는
시뮬레이션하지 않았다**; 실측이 아니라 후속 검증을 위한 분석적 projection이다. 작업 중 upstream ONNXim의
**GQA/MHA `kv_head_idx` 매핑 버그**를 발견·수정·보고했다.

### 2. Queue-Aware FTL Simulator
[projects/ssd-ftl-simulator.md](projects/ssd-ftl-simulator.md) ·
[`queue-aware-ftl-simulator-public`](https://github.com/oyeong011/queue-aware-ftl-simulator-public) **(public)** — 코드·테스트·config·
processed 결과·figure·manifest (raw trace를 포함한 개발 저장소는 private 유지)

**host queue 상태를 보는 GC**가 WAF를 과도하게 키우지 않고 GC 유발 tail latency를
낮출 수 있는지 묻기 위해 page-level FTL + 채널별 NAND 시뮬레이터를 C++17로 직접
작성했다. 정책 3종, invariant 테스트 12개, 5-seed 스윕. 결과: queue-aware가 모든
seed에서 p99를 낮추고 host를 막는 GC stall을 **12.95 % ± 0.23** 줄이며 WAF를
**4.15 % ± 0.10** 지불한다. p99 크기는 σ가 평균의 절반이라 단일 수치가 아니라
방향+범위(2.4~7.4 %)로 보고한다.

### 3. KV-cache Consumer GPU Benchmark
[projects/gpu-kv-cache-benchmark.md](projects/gpu-kv-cache-benchmark.md) ·
[`kv-cache-consumer-gpu-bench`](https://github.com/oyeong011/kv-cache-consumer-gpu-bench) (public)

컨슈머 GPU(RTX 5060/5080)에서 KV-cache 메모리 압력·지연 열화·OOM 경계를 실측하고,
token eviction(SnapKV / H2O 계열)을 추가로 측정했다. KV 바이트는 약속대로 줄지만
**throughput은 오히려 떨어진다**(0.88~0.98×).

### 4. Memory Hierarchy Experiment Framework
[projects/memory-hierarchy.md](projects/memory-hierarchy.md) ·
[`memory-hierarchy-experiment-framework`](https://github.com/oyeong011/memory-hierarchy-experiment-framework) (public)

C 마이크로벤치 + `perf` 자동화로 cache locality, TLB, 접근 패턴, matrix blocking
효과를 Linux에서 측정.

### 보조: RTL / CPU 마이크로아키텍처
Verilog RV32I single-cycle CPU가 직접 작성한 testbench를 통과(COSE222).
파이프라인 버전은 진행 중이며, HW 쪽 문해력 증거로만 포함한다.

---

## 읽는 순서

1. **[JD_TRACEABILITY_MATRIX.md](JD_TRACEABILITY_MATRIX.md)** — SYSTEM SW 요구역량을
   구체 파일과 구체 측정치에 연결. 근거 없는 역량은 `not demonstrated`로 표기.
2. **[APPLICATION_EVIDENCE.md](APPLICATION_EVIDENCE.md)** — 이 포트폴리오의 모든 주장,
   raw 증거 파일, 검증 상태.
3. **[PORTFOLIO_KO.md](PORTFOLIO_KO.md)** / [pdf/portfolio.pdf](pdf/portfolio.pdf) — 국문 원고.
4. 이후 개별 프로젝트 문서.

## 일부 저장소가 private인 이유

NPU 작업은 연구실 환경의 공용 시뮬레이터 호스트에서 수행했고, 연구실이 먼저 발표하고
싶어할 수 있는 negative result와 신규 관찰을 포함한다. 따라서 해당 저장소는 private으로
두고 요청 시 공유하며, 그 산출물 — 서사·모든 수치·raw 증거 위치·정확한 재현 명령 — 은
이 문서에 전부 기록돼 있다.

SSD 시뮬레이터는 전적으로 본인 작업이며 [`queue-aware-ftl-simulator-public`](https://github.com/oyeong011/queue-aware-ftl-simulator-public)에
전부 공개돼 있다. 개발 저장소가
private인 이유는 약 390 MB의 워크로드 trace를 추적하기 때문이며, 그 trace는 공개된
manifest의 seed·인자로 재생성되므로 결과 재현에 필요한 것은 공개본에 빠짐없이 들어 있다.

## 증거 원칙

모든 수치는 저장소의 raw 로그/CSV, 지정된 commit, 그것을 만든 명령까지 추적된다.
각 주장은 다섯 상태 중 하나를 갖는다: `verified-current`(현재 환경에서 재실행,
raw 로그 포함) · `verified-historical`(실제 과거 측정, raw 파일 존재, 재실행 안 함) ·
`documented-not-rerun` · `unsupported`(주장은 있으나 증거 못 찾음 — 지우지 않고 노출) ·
`failed`.

**시뮬레이터 결과는 시뮬레이터 결과로 표기한다.** SSD 프로젝트는 SSD를 *모델링*하며
*측정*하지 않는다. 이 환경에 NVMe 장치가 없고, 여기 어떤 수치도 실물 SSD 성능이 아니다.
