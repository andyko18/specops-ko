# Changelog

[Keep a Changelog](https://keepachangelog.com/ko/1.1.0/) 포맷. [SemVer](https://semver.org/lang/ko/) 준수.

## [Unreleased]

## [1.84.0] — 2026-08-29

> **llm-eval 관측 (20260829, 부분 실행 10/17 — 중단됨)**: `new-1`·`new-2`·`maint-1`·`maint-2` 4건 FAIL(전부 `got=none` — Skill 호출 0회), `new-3`·`none-1~3`·`border-1~2` 6건 PASS.
> - **회귀 증거 아님**: 직전 전수 baseline(2026-08-13)이 **17건 중 8 FAIL** 이었고 4/10 은 그 밴드 안이다. 이번 릴리즈의 산문 변경은 `e2e-test-ko`·`verifying-evidence-ko` 뿐이고 **chain 진입 산문(`using-specops-ko`·`specifying-ko`)은 무접촉**이다.
> - **다만 기록해 둘 불일치**: v1.74.0 항목은 *"`new-1` 은 4턴에서 PASS 하던 fixture 다"* 라고 적었는데 현재 설정(4턴)에서 FAIL 했다. 그 주장은 **되돌린 뒤 실 eval 재검증 미실시**였다고 같은 항목이 스스로 밝혔으므로, 이번 실행이 그 주장의 **첫 검증**이며 결과가 어긋난다. 단발·flaky 하네스라 결론은 아니고 **신호로만** 남긴다.
> - **재실행하지 않는다**: 이 하네스는 자기 문서가 *"신호 감지율을 재고 있지 않다 … eval 이 무엇을 측정할 것인지부터 재정의해야 한다"* 라고 결론 낸 상태다. 재정의 예정인 계측의 숫자를 비용을 들여 선명하게 만드는 것은 낭비다 — 확인은 **재설계 시점**에 한다.

### Added

- **정체 batch 를 `/doctor` 가 본다 (FID 20260829-batch-stall-visibility)** — argus 실측에서 FR **31건이 `IMPL_DONE` 에 멈춘 채 방치**됐고, 그 사실을 아무도 묻지 않았다. v1.81.0 의 `batch-resume-check` 가 SessionStart 에 표면화했지만 **두 구멍**이 남아 있었다:
  - ① **나이가 없다** — `미완 batch — batch-X: 31/34 완료` 가 매 세션 똑같이 나온다. 2주면 벽지가 된다. 이 repo 가 `skip-tracker` advisory 에서 이미 겪은 형태이고, 이번 릴리즈에서 두 번 더 진단한 것과 같은 병이다.
  - ② **`ACTIVE` 마커에만 의존한다** — 마커 없이 방치된 미완 queue 는 **아예 안 보인다**. 마커 제거는 Step D 성공 경로라, 그 전에 버려진 batch 는 탐지 밖이었다.
  - `doctor` 의 `stale` 축(적체·정체·우회)에 얹었다 — 이미 일수 임계로 "가만히 앉아 있는 것" 을 모으는 자리다. 새 `_chk_batch` 를 만들지 않았고, 라벨 정규화는 `queue-lib.sh` 를 재사용한다(자체 정규식을 쓰면 `20260828-queue-label-drift` 가 고친 드리프트를 소비자 하나에 되살린다).
  - 판정: `SKIP` 을 분모에서 뺀 완료율 미달 = 미완. **전 FR 완료 + `ACTIVE` 잔존 = Phase 3 미실행**(argus 가 정확히 이 상태였다)도 미완으로 본다. 전 FR 완료 + 마커 없음 = Step D 정상 종결이라 보고하지 않는다. 임계 기본 14일(`DOCTOR_BATCH_STALE_DAYS`).
  - doctor 계약 유지 실측: **0.55초** · 네트워크 0 · 파일시스템만(per-FID spawn 없음) · read-only.
  - 어서션 5건. `T-bs.d`·`T-bs.e` 가 되돌려-관찰 — 1일된 batch(진행 중)와 종결 batch 를 정체로 부르지 않는다(오탐 차단).
  - ★ **한계 고백 — 문제 A 는 도구로 닫히지 않는다**: 사례 연구의 일반화가 *"세션이 끝나면 이어받을 주체가 없다"* 인데, 그건 **모델이 들고 있는 오케스트레이션 루프의 성질**이다. `/start-all` 은 산문이고 batch 를 재개시킬 프로세스가 없다. 도구가 살 수 있는 것은 **탐지와 재개성**뿐이며, 이 변경은 그중 탐지를 나이·마커 무관으로 넓힌 것이다. 정체 클래스가 제거됐다고 읽으면 안 된다.

### Changed

- **pretool mutation 36% → 84% (FID 20260829-pretool-mutation-triage)** — 직전 릴리즈에서 세운 baseline(`killed=9 survived=16`)의 생존 16건을 전수 분류했다. `pretool-governance.sh` 는 **차단 판정 본체**(R-1/R-2 deny)라 여기가 비면 게이트 전체가 신뢰를 잃는다.

  | | 종전 | 현재 |
  |---|---|---|
  | killed | 9 | **11** |
  | survived | 16 | **2** |
  | equivalent | 0 | **12** |
  | score | 36% | **84%** |

  - **신규 테스트로 격추 2건** — 둘 다 보안 계약이다. `L219`(`transcript` 부재 시 **fail-open**): 변이가 뒤집으면 transcript 없는 정직한 사용자가 통째로 막힌다. `L397`(`hard` 분기): 변이가 뒤집으면 **hard deny 가 allow 로** 반전되는데 어떤 테스트도 울지 않았다 — `T-batch.b` 는 정직 batch(`any_not_ready=0`)라 L395 에서 반환해 397 에 닿지도 않았다.
  - ★ **초안 `T-mut.c` 는 tautology 였고 되돌려-관찰이 잡았다**: 산출물 없는 batch 를 쓰면 `_batch_pr_gate` 가 **먼저** deny 해 L397 에 도달조차 안 한다 — 변이를 넣어도 테스트가 통과했다. batch 게이트는 통과시키고(산출물 완비) release-ready 축 하나만(bare SKIP) 깨뜨려 정확히 L397 에 도달시키도록 고쳤다. 테스트가 green 인 것은 변이를 죽인다는 증거가 아니다.
  - **equivalent 12건은 근거를 확인하고 등재**했다 — `return 0` 10건은 두 게이트 함수가 **bare 호출**(`L132`·`L414`)이라 rc 가 어디에도 안 쓰이고 deny 는 `exit 0` 으로 나간다(호출부 직접 확인). `L19` 는 다음 줄 `cd … || true` 가 실패를 흡수해 `-d` 검사가 중복이다. `L364` 는 파일 부재 시 `eff` 가 빈 값이라 strict 분기에 안 들어간다.
  - ★ **남은 생존 2건은 정직하게 생존으로 둔다** — equivalent 가 아니라 진짜 미검이다. `L193`(R-1-SCOPE **info 기록** 조건, 판정 무관·계측 데이터만 변함) · `L361`(batch fids 목록을 단일 `detect_fid` 로 덮어쓰는 변이, 목록≠detect_fid 픽스처 부재). 근거 없는 equivalent 등재는 자기발급 면제표이고 이 repo 가 `§auto`·bare SKIP 에서 두 번 없앤 패턴이라, **확인 못 한 것은 등재하지 않는다**.

## [1.83.0] — 2026-08-29

### Fixed

- **테스트 fixture 가 repo 의 활성 FID 를 점거했다 (FID 20260829-fixture-fid-hijack)** — `/e2e-test` 를 한 번 돌리면 그 뒤 **모든 커밋이 fixture 의 verify 상태를 대신 answer** 해야 했다(R-1 ②앵커). 게다가 fixture 테스트는 `.specops/<FID>/*.sh` 라 `run-verification` 실행 whitelist 밖이어서 **구조적으로 PASS 를 낼 수 없다** — 정직한 탈출구가 없어 BYPASS 만 남았다. **이번 세션 BYPASS 3건이 전부 이 하나의 결함에서 나왔다.**
  - **원인은 2순위가 아니라 1순위였다**: 처음엔 `detect_fid` 의 "첫 `## <FID>` 헤더" fallback 을 의심했는데, 실측하니 `session-progress-append.sh` 가 append 하는 FID 로 `active-fid` 마커를 **자동 생산**하고 있었다(FID 20260809-active-fid-marker-producer). e2e 는 12스텝 내내 append 를 부르므로 마커가 fixture 로 덮인다. 소비자가 아니라 **생산자**를 고쳐야 하는 문제였다.
  - 판별자는 `.specops/<FID>/.fixture` 마커 **파일**이다 — 산문·헤더 포맷을 파싱하면 e2e 가 표기를 바꿀 때 조용히 깨진다(이 repo 의 queue 라벨 드리프트와 동형). 파일 존재는 포맷 무관이고 후보당 test 1회라 hot path 비용이 없다.
  - 두 층 모두에 걸었다: 생산자는 fixture 를 마커로 **승격하지 않고**, 소비자 `detect_fid` 2순위 fallback 도 fixture 를 **건너뛴다**. 사람이 마커를 손으로 써서 fixture 를 지목하는 것은 여전히 존중된다(1순위 불변 — 5원칙 4 주권).
  - **섹션 기록 자체는 남긴다** — 막는 것은 *활성 지목*뿐이고 증거는 보존된다(T-fx.c).
  - 어서션 8건(`detect_fid` 5 + `session-progress-append` 3). `T-fx.a`·`T-fx.e` 가 되돌려-관찰 — fixture 마커가 없으면 종전 동작 그대로다(과잉 일반화 차단).
  - **남은 한계**: fixture FID 자체는 여전히 `VERIFY: PARTIAL` 로만 끝난다(테스트가 실행 whitelist 밖). whitelist 확대는 실행 allowlist 확장이라 **보안 판단**이 필요해 별건으로 남긴다 — 활성 FID 를 점거하지 않게 된 이상 실사용을 막지는 않는다.
  - 부수 관찰(미수정): `session-progress-append.sh` 는 대상 파일에 `---` 앵커가 없으면 섹션을 **조용히 드롭**하면서 `created new section` 을 출력한다. 실 파일은 `ensure-session-progress` 가 템플릿으로 보장하므로 실사용 영향은 없으나 출력과 실제가 어긋난다.
  - ★ **직전 커밋에 신설한 `test-mutation-conf-fresh` 가 이 변경에서 즉시 발화했다** — `detect_fid` 편집으로 equivalent conf 3건이 stale 이 됐고 run-all 이 red 로 잡았다. 종전이라면 아무도 몰랐다.

### Added

- **mutation conf 신선도를 상시 게이트로 (FID 20260829-mutation-coverage)** — `mutation-equivalent.conf` 는 **절대 줄번호**로 equivalent mutant 를 지정한다. target 이 자라면 조용히 어긋나고, 어긋난 항목은 매칭 0건이 되어 정상 변이가 제외되지 못한 채 **score 가 거짓 하락**한다(conf 주석 실측: 64% → 50%). 판정기 `--check-conf` 는 **1초**면 끝나는데 `mutation-score.sh` 가 run-all 명명 규칙(`test-*.sh`) 밖이라 아무도 안 돌렸고, **이번 세션의 `governance-lib.sh` 편집 3건으로 16/18 이 stale** 이 됐다 — 그동안 어떤 게이트도 울지 않았다.
  - 신규 `test-mutation-conf-fresh.sh` — 무거운 mutation 실행은 수동으로 두고 **1초짜리 정합만** run-all 에 넣는다. conf 신선도(T2) + targets 경로 실재(T3, 오타 시 "대상 0건 조용한 통과" 차단) + 게이트 핵심 3종 커버 강제(T4).
  - stale 16건은 이전 정상 리비전의 앵커 블록으로 **재정렬**해 18/18 복구했다(추측 아님 — 옛 파일에서 5줄 블록을 떠 현재 파일에서 유일 매칭을 찾았고, 실패 0건).
- **mutation 측정 대상 2종 추가 + baseline 실측** — 종전 대상은 2파일뿐이었다.

  | 대상 | killed | survived | score | 소요 |
  |---|---|---|---|---|
  | `scripts/_internal/run-bounded.sh` | 2 | 0 | **100%** | 17s |
  | `hooks/pretool-governance.sh` | 9 | 16 | **36%** | 431s |

  - `pretool-governance.sh` 는 **차단 판정 본체**(R-1/R-2 deny)인데 36% 다. 커버 스위트는 `test-pretool`+`test-rules`+`test-hooks` 를 묶었다 — 좁게 잡으면 `governance-lib` 이 겪은 "32% false rot" 이 재발한다.
  - ★ **생존 16건을 equivalent 로 몰아 점수를 올리지 않았다** — 근거 없는 equivalent 등재는 자기발급 면제표이고, 이 repo 가 `§auto`·bare SKIP 에서 두 번 없앤 바로 그 패턴이다. 생존 분류는 별건 backlog 로 남겼다(`&&` 5건·`-eq` 1건이 우선 후보, `return 0` 11건은 stdout-contract 계열 가능성).

### Changed

- **`/doctor` 의 memory·bootstrap ⚠️ 는 정책의 알려진 결과임을 CLAUDE.md 에 명시** — 두 경고는 **정확한 보고**다. `.specops/` 전량 로컬 전용 정책(`3061f93`)의 직접적 결과이고, `init-finalize.sh` 를 돌려도 대상이 전부 ignore/tracked-clean 이라 **no-op** 이다. `doctor.sh` 를 고쳐 끄지 않는다 — 플러그인을 만들면서 specops 를 쓰는 하류 사용자의 **진짜 경고까지 죽는다**. 경고를 무시하는 것과 방향만 반대인 같은 병이다.

### Changed

- **근거 없는 SKIP 을 PR 게이트에서 차단한다 (FID 20260829-bare-skip-teeth)** — lifecycle 후반 3게이트(security·integration·performance)는 실측 **87회 평가에서 FAIL 0건**이고 SKIP 비율이 integration 72%·performance 55% 다. SKIP 판정 주체가 **모델 자신**이라, 근거 없는 SKIP 은 v1.45.0 이 제거한 `§auto` 자기발급 면제표와 같은 클래스다 — 라벨만 안 쓸 뿐 "내가 해당 없다고 했으니 넘어간다"는 동일하다. 세 skill 본문은 이미 *"근거 없는 SKIP 은 형식화 — 거부"* 를 선언하는데, **그 선언에 대응하는 기계 검사가 없었다**(`skip-tracker` 는 advisory — 이 repo 가 advisory 를 방치한 전례 그 자체다).
  - `release-ready.sh` 에 `skip_cite` 축 신설 — `SKIP` 은 `**근거**` 에 `L<번호>`·`§…<번호>` 인용을 요구하고, 없으면 `NOT_READY`. `_release_ready_gate`(R-2 / `gh pr create`)의 기존 hard/warn 분할을 그대로 탄다(strict FID·ACTIVE batch → hard).
  - ★ **왜 verify 관문이 아니라 PR 게이트인가**: chain 순서상 `/verify` 는 세 게이트보다 **먼저** 온다(`verifying-evidence → … → security → integration → performance`). verify 시점엔 evidence.md 에 세 섹션이 아직 없다 — 거기 걸면 항상 통과하거나 항상 오탐한다. 세 판정이 모두 존재하는 유일한 순간이 PR 직전이다.
  - ★ **왜 warn 이 아니라 하드인가**: 소급 FAIL 이 **실질 0** 이다. bare 보유 FID 8건(판정 보유 23건의 34%)이 **전부 종결**이고 열린 PR 0건이다(실측). `check-review-presence` 가 35% 소급 FAIL 때문에 warn 으로 남은 것과 숫자는 같지만 **대상이 다르다** — 저건 살아있는 FID 였고 이건 이미 끝난 것들이라 앞으로의 PR 에만 걸린다.
  - **부수 결함 적발**: `skip::cite_status` 가 헤더 겸용 형태(`## /gate SKIP`)에서 **헤더 한 줄만 보고 BARE 로 확정**해, 바로 다음 `**근거**: §범위 L12-15` 를 읽지도 않고 정직한 인용을 bare 로 세고 있었다. advisory 였을 때는 아무도 틀렸다는 걸 몰랐다 — **하드로 올리는 순간 자기 테스트 fixture 6건이 깨져서 드러났다**. 계측기를 게이트로 승격하면 계측기의 거짓말이 드러난다.
  - 인용 SoT 는 `skip::cite_status` 하나다 — `skip-citation-sot` 원장이 소비자 3곳(release-ready·e2e stub)을 결속한다. e2e S6.5 stub 도 인용하도록 고쳤다(안 고치면 하네스가 자기 PR 게이트에 걸린다).
  - **한계 고백**: 인용 판정은 `L<숫자>` **토큰 존재**만 본다. `§범위 L999` 처럼 실재하지 않는 라인을 인용해도 통과한다 — 근거를 **쓰게** 만들 뿐 근거가 **참인지**는 검증하지 않는다. 라인 실재 대조는 별건으로 남긴다.
  - **후속 backlog (미해결, 문서화만)**: `/e2e-test` 실행 후 fixture FID 가 repo 의 **활성 FID 를 점거**한다 — `detect_fid` 가 `active-fid` 마커 부재 시 첫 `## <FID>` 헤더를 쓰기 때문이다. 게다가 fixture 테스트는 `.specops/<FID>/test-greet-cli.sh` 라 `run-verification` 실행 whitelist(`bash (scripts|tests)/*.sh`) 밖이어서 **구조적으로 PASS 를 낼 수 없다**. 결과: e2e 이후 모든 커밋이 fixture 의 verify 상태를 대신 answer 하며 R-1 ②앵커에 막힌다(이번 세션에서 2회 실측). 하네스에 회피책을 적었고, 근본 해결(활성 후보 제외 vs 실행 allowlist 확대)은 보안 판단이 필요해 별건으로 남긴다.
  - 어서션 4건(RR-cite.a~d). `RR-cite.d` 가 되돌려-관찰 — `PASS` 판정에는 인용을 요구하지 않는다(과잉 일반화 차단).

## [1.82.0] — 2026-08-29

### Added

- **SKILL.md 크기 래칫 (FID 20260828-skill-size-ratchet)** — lifecycle chain 12 skill 의 SKILL.md 합계가 **223,823 B / 3,611 줄**이다(대략 5만 토큰 — bytes÷4.4 기준, 추정치임을 명시한다). 단일 최대는 `specifying-ko` 49.5 KB, 줄 수 최대는 `e2e-test-ko` 1,018 줄. 지시 희석은 이 repo 가 반복해서 겪은 "조용히 잘못되는" 실패의 유력 원인인데, **어떤 게이트도 이 축을 보지 않았다**.
  - `validate-structure` 신규 검사 `skill_size` — `.skill-size-baseline` 에 skill 별 bytes·lines 와 chain 집계를 기록하고 **초과하면 FAIL**. 늘리려면 `--update-baseline` 으로 명시 갱신해 diff 에 의도를 남긴다.
  - ★ **임계 경고가 아니라 래칫인 이유**: 이 repo 에는 advisory 가 이빨 없이 방치된 전례가 있다(`skip-tracker` 가 SKIP 71%·근거 없는 SKIP 15건을 경고만 하고 있다). 임계값을 발명하지 않아도 되고, 49.5 KB SKILL.md 를 만든 드리프트 경로를 닫는다.
  - chain 집계 대상은 `hooks/chain.yaml` 의 from/to 합집합에서 **도출**한다 — 목록을 lint 에 복제하면 edge 변경 시 조용히 stale 이 된다(`chain_consistency` 가 이미 잡는 클래스를 새로 만드는 셈). `T2.b` 가 하드코딩 배열을 금지한다.
  - **bytes·lines 만 잰다** — 토큰 수는 추정이라 실측 문화의 게이트가 지어낸 수치를 내면 안 된다. 토큰 환산은 산문의 몫이다.
  - 한계 고백: **SKILL.md 본문만** 잰다(= 컨텍스트로 로드되는 것). 본문을 보조 파일로 옮기면 수치가 준다 — 그게 의도(온디맨드 읽기)지만 "보조 파일이 정말 온디맨드인가"는 기계가 못 본다. 분할 리뷰에서 사람이 확인해야 한다.
  - 어서션 8건. `T4.a` 가 되돌려-관찰이다 — 실제 skill 을 부풀려 **FAIL 전환을 실측**하고 원복한다(`T4.b` 가 트리 무오염 확인). 래칫이 "있는데 안 무는" 상태가 가장 나쁘고, 그건 위 `skip-tracker` 와 동형이다.

### Fixed

- **E2E V12 가 구현보다 오래된 계약을 들고 있었다 (FID 20260829-e2e-v12-contract)** — `/e2e-test` **실주행으로 적발**했다(PASS=23 FAIL=1). `init-project` Phase 10 은 *"스테이징 완료 … Phase 11 enrich 후 단일 커밋하세요"* 로 커밋을 뒤로 미루는데, `V12` 는 여전히 `git log >= 1` 을 요구해 **기본 경로에서 구조적으로 FAIL** 이었다. `/e2e-test` 가 수동 전용이라 `run-all` 이 못 봤고, 이 repo `doctor` 의 *"부트스트랩 미종결 · init 커밋 0"* 경고도 같은 원인이다.
  - 정정: 기본 경로는 **staged > 0 · 커밋 0**(현 계약), 커밋 경로는 `SPECOPS_INIT_COMMIT_NOW=1` 로 **따로 실증**한다. 둘 다 봐야 "스테이징만 하고 커밋은 Phase 11" 계약에 이빨이 선다 — 한쪽만 보면 다시 드리프트한다. 실측: 기본 `staged=10 commit=0`, 커밋 경로 `commit=1` → V12 PASS.
- **E2E S7·S8 이 R-1 에 구조적으로 막혔다** — 두 단계는 `mktemp -d` throwaway repo 안에서 `git commit` 을 부르는데, PreToolUse R-1 은 **명령 문자열**만 보므로 sandbox 인지 구분하지 못한다. 세션에 fresh verify 증거가 없으면 `/e2e-test` 가 S7 에서 통째로 막힌다. 하네스에 두 경로(사전 `run-all` 실행 / 각 `git commit` 에 **인라인** 우회)를 명시했다. 별도 줄의 `export` 는 소용없다는 것도 함께 적었다 — 훅은 별도 프로세스라 셸 환경이 아니라 명령 문자열을 읽는다(실주행에서 실제로 헛짚었다).

### Changed

- **`e2e-test-ko` 시범 분할 — fixture 본문을 보조 파일로 (FID 20260828-skill-split-pilot)** — `1,018줄 / 37,452 B` → **`729줄 / 30,979 B`**. 사용자 코딩 규칙(800줄 max)을 위반하던 유일한 SKILL.md 였다. 옮긴 것은 lifecycle 산출물 fixture 5종(`spec`·`acceptance-criteria`·`clarifications`·`plan`·`tasks`) 본문 — **순수 페이로드**이고, 해당 스텝에서 한 번 쓰이는 데이터다. `skills/e2e-test-ko/fixtures/*.md` 로 옮기고 SKILL.md 에는 "이 파일을 읽어 `.specops/$FID/<파일>` 에 생성한다" 2줄 포인터만 남겼다.
  - **본문 무손실 실측**: 추출 5건 전부 원본 블록과 **byte-identical**(스크립트로 대조). 포인터가 원래 리드인이 담던 목적지 경로·플레이스홀더 치환 지시를 모두 승계한다 — 초안에서 목적지 경로가 빠진 것을 발견해 복원했다.
  - **신규 skill 디렉토리를 만들지 않았다**: `skills/<name>/SKILL.md` 를 늘리면 `.structure-baseline` 카운트·`used_by`·`chain_consistency`·메타 skill 목록·`readme_counts` 4~5개 게이트를 동시에 건드린다. 기존 선례(`planning-ko/plan-document-reviewer-prompt.md`·`brainstorming-ko/scripts/`)대로 skill 디렉토리 내 보조 파일을 쓴다.
  - ✅ **행동 검증 완료 (사후)**: `/e2e-test` 1회 실주행으로 확인했다. S1~S4 를 **분할본 지시(fixtures 포인터)** 로 수행해 산출물이 fixture 와 `<FID>`·`<날짜>` 치환만 다른 **byte-identical** 임을 대조했고, `V2`(spec §1·§2·§5)·`V3`(AC 3개)·`V4`·`V5`·`V6`(DAG YAML)·`V8`(DAG leaf) 전부 PASS 했다. 최초 커밋 시점에는 미검증이었고 그렇게 명시했었다 — `run-all` green 은 분할 안전의 근거가 아니다(P1-6 을 자기 변경에 적용하지 않는다).
  - 나머지 chain skill 은 이번에 건드리지 않았다. `specifying-ko`(49.5 KB) 는 lifecycle 진입점이고 진입 분기 7종을 순서 매칭하므로 blast radius 가 가장 크다 — 시범 결과와 행동 검증 수단을 확보한 뒤에 다룬다.

### Fixed

- **deny 사유가 원인을 거짓으로 말해 BYPASS 를 유도했다 (FID 20260828-deny-cause-truth)** — 러너를 정직하게 완주한 뒤 파일을 고치면 stale 로 막힌다(판정은 옳다). 그런데 문안은 *"이 세션에 러너 실행 기록이 없습니다"* 였다. 사용자는 방금 돌린 수분대 러너를 또 돌리거나, 게이트를 결함으로 의심하고 우회한다.
  - **실측**: 마찰로그 `BYPASS-ENV` 24건 중 **15건이 "이 세션에서 verify PASS" 를 사유로 적었다** — 증거가 있었는데 막힌 것이다. 그중 4건은 아예 *"R-1 게이트 결함 의심"*·*"게이트 결함(구성요소 rc=0, 통합만 deny)"* 이라고 썼다. 이번 세션에서 **분석자 자신도 같은 함정에 빠져** jq 를 읽고서야 원인이 staleness 임을 알았다.
  - 틀린 deny 문안이 BYPASS 를 유도한 것은 **두 번째**다 — v1.45.0 이 *"verify 미실행"* 이라는 거짓 단정 때문에 같은 이유로 문안을 교체했다.
  - 신규 `_verify_stale_cause` — **판정에 관여하지 않는다**(deny 경로 전용 진단, `_bg_pending_path` 와 같은 패턴). 러너 PASS 증거가 있는데 그 뒤 코드 편집이 있으면 `stale <마지막 편집 파일>` 을 돌려주고, 문안이 "러너는 PASS 했으나 그 뒤 코드가 수정됐습니다 / 마지막 수정: <경로> / 한 번 더 실행하세요" 로 바뀐다. 진단 실패·비대상 경로는 **빈 값 → 종전 문안**(미탐 방향으로만 떨어진다).
  - 어서션 4건(T-stale.a~d) + fixture `pretool-verify-then-edit.jsonl`. `T-stale.d` 가 되돌려-관찰이다 — 증거가 **정말로** 없는 경로는 종전 문안을 유지해야 하며, 과잉 일반화를 잠근다.
  - **초안 폐기 기록**: 처음엔 `git add <파일들>` ⏎ `git commit` 형태가 작업트리 범위로 떨어지는 스코프 문제(P0-2)를 고치려 했다. 수율을 먼저 실측했더니 BYPASS 24건 중 **그 형태로 설명되는 것은 1건**뿐이었다(2건은 v1.82.0 이후 `skills/*` 라 어차피 code, 1건은 `-A` 라 작업트리 범위가 이미 정확). 게이트를 **여는** 방향의 셸 파싱 변경(같은 함수에서 인용 파싱이 두 번 false-open 으로 실패한 이력이 있다)을 1건을 위해 감수할 이유가 없어, 같은 마찰(BYPASS 압력)의 지배적 원인 15건을 치는 이 변경으로 대체했다.

- **docs-only 면제가 플러그인 런타임 전체를 면제하고 있었다 (FID 20260828-md-runtime-scope)** — `_files_all_docs` 는 `*.md` 를 전부 문서로 본다. 그런데 이 플러그인의 **실행 로직은 산문**이다 — `skills/*/SKILL.md` 한 줄이 chain 동작을 바꾼다. 즉 "commit 전 verify" 강제가 **제품 본체에서 통째로 면제**됐다. v1.45.0 에서 제거한 `§auto` 자기발급 면제표보다 넓다 — 모델이 라벨을 쓸 필요조차 없었다.
  - **실측(최근 60커밋)**: 종전 규칙으로 54건이 면제 클래스. 신규 규칙은 41건을 코드로 재분류하고 13건만 면제로 남긴다. 재분류 41건 중 19건은 릴리즈/버전 스탬프(`release.sh` 가 in-session 으로 run-all 을 돌려 증거가 이미 있다)이고, **22건이 실제 행동 변경**이다 — `feat(design): 화면 품질 게이트`·`fix(batch): 라벨 드리프트가 teeth 를 무음 해제`·`fix(hook): SessionStart 조립 순서` 등.
  - **규칙**: `.claude-plugin/plugin.json` 이 있는 repo 에서 `skills/*/SKILL.md`·`commands/*.md`·`agents/*.md`·`templates/*.md`·`hooks/*`·`.claude-plugin/*` 은 확장자와 무관하게 코드.
  - ★ **플러그인 repo 조건이 본체다**: 이 경로들은 Claude Code **플러그인 규약**이지 앱 규약이 아니다. 조건 없이 걸면 하류 앱 repo 의 `templates/email.md`·`docs/agents/x.md` 가 문서 커밋에서 막힌다 — false-deny 는 정확히 BYPASS 관성을 만든다(마찰로그 BYPASS 24건/30일이 그 증거다). 같은 트리라도 `skills/*/README.md`·루트 `README`·`CHANGELOG`·`CLAUDE.md` 는 면제 유지(배포 런타임 아님).
  - 매처는 pretool(차단)·posttool(감사)·`_commit_scope_class`(계측) 3곳이 공유한다 — "면제 클래스 ≡ 분류 클래스" 불변식이 함께 움직이는지 T-plug.k 가 잠근다(안 그러면 20260814-friction-scope-posttool 이 고친 계측 불일치가 재발한다).
  - 어서션 **11건 신규**(T-plug.a~k). end-to-end 프로브: 플러그인 repo + `skills/foo/SKILL.md` staged → **deny**, `docs/a.md`·`CHANGELOG.md` → allow, 비플러그인 repo → 전부 allow(종전 동작 보존).
  - **분석 정정**: 최초 조사에서 이 결함을 "pretool 이 allow 를 냈다" 로 보고했으나, 그 프로브는 transcript 부재로 **fail-open** 경로를 탄 것이었다. 면제 자체는 `is_docs_only_change` 단위 판정으로 실재했고, fixture transcript 를 물린 end-to-end 프로브로 이제 정확히 재현된다.

- **`run-all` 무한 정지 — pre-push·릴리즈 pre-flight 가 네트워크에 묶여 있었다 (FID 20260828-sast-timeout)** — `scripts/security-scan.sh` 의 `semgrep --config auto` 는 레지스트리에서 룰을 받는 **네트워크 호출**이고 자체 상한이 없다. `run-all.sh` 에도 스위트별 상한이 없어, 한 스위트가 멈추면 aggregator 가 통째로 멈췄다 — 그리고 그 게이트를 `.githooks/pre-push` 와 릴리즈 pre-flight 가 그대로 쓴다. 즉 **`git push` 가 무한 정지**했다. 실측: `run-all` 이 `test-security-scan` 에서 **8분+ 무출력** 후 강제 종료. CI(ubuntu)는 semgrep 미설치라 graceful skip 되므로 **로컬 개발 환경에서만 발화하는 함정**이었고, friction-log 의 BYPASS 사유 *"러너를 단일 도구호출 내 완료 불가"* 2건이 같은 증상과 부합한다.
  - 신규 `scripts/_internal/run-bounded.sh` — `bounded_run <초> <명령…>` 공용 상한 헬퍼. `run-all`(스위트별 300s)·`security-scan`(외부 스캐너별 180s)이 소비한다.
  - ★ **GNU `timeout` 도 `perl alarm` 도 답이 아니다** — 둘 다 대상 프로세스 하나만 죽인다. 대상이 래퍼 셸이면 고아가 된 손자가 stdout 파이프를 계속 물어 `$( )` 가 반환되지 않는다. 상한은 걸렸는데 **호출부는 그대로 멈춘다**(실측: perl alarm 2s 구현에서 `bounded_run` 은 2초, `j=$(…)` 는 **102초**). `set -m` + `kill -- -$pid`(프로세스 그룹째)로 전 자손을 잡는다 — `check-ci-status.sh:_run_with_timeout` 이 이미 실증한 메커니즘이고, 두 구현의 드리프트는 `bounded-run-watchdog` 원장이 잠근다.
  - ★ **워치독을 신호로 죽이면 안 된다** — 비대화형 bash 가 다음 명령 경계에서 `Terminated: 15 …` 를 stderr 에 흘리고, `wait 2>/dev/null` 로는 못 막는다(알림 시점이 wait 밖). 스위트마다 부르므로 148배로 불어난다. 부모는 flag 파일만 지우고 워치독이 **스스로 정상 종료**한다 — 대기 비용 0, stderr 무오염(T6.a 가 잠금).
  - **무음 강등 차단**: 시간초과·하드 실패(rc≥2) 모두 출력에 명시한다. 상한만 걸고 표기를 빠뜨리면 정지가 **조용한 `crit=0` 통과**로 바뀐다 — 정지보다 나쁘다.
  - **부수 발견 ①**: `--metrics=off` 는 `--config auto` 와 **비호환**이다(`Cannot create auto config when metrics are off`). 붙이면 semgrep 이 통째로 no-op 이 되는데 출력은 `SECURITY: crit=0 high=0` 이다. 도입 시도했다가 실측으로 되돌렸고, 그 경험이 위 "하드 실패 표기" 를 낳았다.
  - **부수 발견 ②**: 이 환경의 실 `semgrep --config auto` 는 **99초 뒤 rc=2 로 실패**한다. 즉 SAST 는 이미 무음 no-op 이었고 `SECURITY: crit=0` 만 나가고 있었다. 이제 `(외부 SAST 미반영 — semgrep(실행실패 rc=2))` 로 표면화된다.
  - **네트워크 금지 계약**: `run-all` 이 `SPECOPS_SAST_EXTERNAL=0` 을 export 한다. 스위트가 실 스캐너를 부르면 테스트 결과가 네트워크 상태에 좌우된다(실측 `test-self-config-collect` 4.4s → **104s**). 스캐너 동작 자체는 stub 으로 검증한다.
  - 테스트 **19건 신규** — `test-run-bounded.sh` 14건(고아 손자 T5·stderr 무오염 T6·배선 T7 포함) + `test-security-scan.sh` AC-4·5·6·7·8. `test-run-all-verify-token.sh` T4(헬퍼 부재 시 무음 아닌 경고 fallback)·T5(네트워크 금지 계약).
- **문서 소요 스탬프 드리프트** — `run-all` 을 8곳이 `~195s`·`144 스위트` 로 적고 있었다. 실측 **331s · 148 스위트**로 정정(CLAUDE.md·README·scripts/README·docs/architecture·pre-commit·pre-push·install-git-hooks·verifying-evidence-ko).

## [1.81.0] — 2026-08-28

> **주제: "조용히 잘못되는" 구조를 없앤다.** 이번 릴리즈의 6건은 전부 같은 병을 고친다 — 게이트가 잡아야 할 것을 놓치면서 **놓쳤다는 사실조차 알리지 않는** 구조다. 계기는 `llm-smoke` mutation job 의 무음 red 였고, 그 조사가 downstream 프로젝트(`Argus`) 실사용 데이터 분석으로 이어져 같은 클래스 결함 3종을 더 찾았다.

### Fixed

- **mutation-equivalent.conf stale 복원 + stale 감지 teeth + 주석줄 변이 skip (FID 20260827-mutation-conf-stale, #10)** — `llm-smoke` mutation job 이 red 였다. 원인은 테스트 갭이 아니라 **설정 부패**다. conf 의 18개 항목이 전부 stale 이라 `equivalent=0` 이 되어, 분모에서 빠져야 할 18건이 survived 로 집계됐다. conf 가 **절대 줄 번호로 키를 잡는데** `governance-lib.sh` 가 1276줄로 자라면서 전부 어긋났다. `b76e9bb` 가 "31%→64% 정직화" 했던 그 64% 가 **무음으로 50% 까지 썩었다**.
  - **W-1 conf remap** — 18행의 `line` 컬럼만 교체. `target`·`pattern`·`reason` 은 바이트 동일(`is_equivalent` 가 `target|line|pattern|` 로 매칭하므로 다른 컬럼을 건드리면 키가 깨진다). **`|&&|` 키는 추가하지 않았다** — L1258·L1266 의 `&&` 변이는 killed 이고 원저자가 `(&& 변형은 미제외)` 로 분모에 남긴 의도다.
  - **W-2a 주석 줄 skip** — 변이 루프가 `grep -nF` 로 주석 줄도 잡아, 주석의 `&&` 를 `||` 로 바꿔도 동작이 같으니 `bash -n` 통과 후 **영원히 survived** 였다(실측 2건 L419·L546). 판정은 **선행 공백 제거 후 첫 문자가 `#`** 인지로만 한다 — 줄 안 `#` 존재로 skip 하면 `[ "$x" = "true" ] && return 0  # PASS` 같은 **코드 줄이 사라져 점수가 거짓 상승**한다.
  - **W-2b stale 감지 (본 FID 의 teeth)** — `mut::check_conf` 가 매칭 사이트 0건인 항목을 보고하고 **채점 진입 전 ABORT** 한다. `mutation-score.sh` 의 baseline sanity 와 **대칭**이다: 그쪽은 stale 로 인한 거짓 **통과**를, 이쪽은 stale 로 인한 무음 **red** 를 막는다. 종전엔 방향이 하나뿐이라 equivalent 18건이 전량 무음 사망해도 아무도 몰랐다. `--check-conf` 독립 모드로 18분이 아니라 **1초**에 확인한다.
  - 실측: `equivalent` 0 → **18**, score 50% → **60%**(baseline 55). main `llm-smoke` 에서 08-17·08-24 2주 연속 실패 이후 첫 성공 확인.
  - **한계**: 줄 번호 키는 여전히 취약하다. 함수명+순번 재설계는 검증 왕복이 18분이라 기각했고, 대신 **drift 가 조용하지 않게** 만들었다.

- **queue.md 라벨 표기 드리프트가 하류 teeth 를 무음 해제하던 것 차단 (FID 20260828-queue-label-drift, #13)** — 생성기 `init-batch-queue.sh:107` 은 Status 를 맨 문자열(`PENDING`)로 쓰는데, 이후 갱신은 `start-all.md` **산문 지시**를 받은 **모델 손편집**뿐이었다. 모델이 `**IMPL_DONE**`(굵게)로 적자 소비자 3곳이 전건 불일치했다.
  - **결과는 오탐이 아니라 무음 통과다.** 산출물·review-skip 검사가 `IMPL_DONE` 행만 수집하므로 **대상 0건 → 조용히 pass**. downstream 실측(`Argus batch-20260729`)에서 FR **31건**이 무검증으로 남았는데 아무도 red 를 보지 못했다.
  - 소비자 3곳이 전부 깨졌다 — `batch-state.sh:92`(31건 "미완" 오판) · `collect-assumptions.sh:26`(대상 0건) · `record-batch-gate.sh:49`(`IMPL_DONE FID 0건` exit 1 → **Step A/B/C 를 정상 수행해도 verdict 전파 실패로 batch PR 이 막힌다**).
  - **`scripts/_internal/queue-lib.sh` 신설(단일 출처)** — 쓰는 쪽(모델 손편집)은 강제할 수단이 없고 소비자는 셋인데 **정규화 지점은 하나로 수렴**하므로 읽는 쪽에서 흡수한다. **흡수 범위는 표기 장식만**(굵게·백틱·기울임·공백·CRLF)이고 **라벨 내용은 바꾸지 않는다** — `DONE`·`PLAN_DONE` 은 그대로. 정규화가 과하면 **미완을 완료로 만들어 원 결함보다 나쁘다**.
  - **라벨 오염 검사를 기본 모드로 승격** — 종전 `--gate` 전용이라 하류 teeth 가 꺼진 사실을 **PR 시도 전까지 아무도 몰랐다**. `batch-state.sh` **주석 L45 가 이 위험을 이미 경고**하고 있었는데, 그 경고를 실행하는 검사가 조용한 구간에서 안 돌았다.
  - **`scripts/_internal/queue-set-status.sh` 신설** — 손편집 경로를 끊는다. **마지막 컬럼만 치환**(행 재조립하면 설명 컬럼의 한국어·em dash 를 잃는다) · 알 수 없는 라벨 거부 · FR-ID 중복 거부 · 행 수 변동 시 미덮어씀. `start-all.md` Phase 1·3 배선. **extglob `@(...)` 을 쓰지 않았다** — 셸 옵션에 의존하면 호출 환경에 따라 검증이 조용히 꺼지는데, 그건 이 FID 가 막으려는 것과 같은 형태다.
  - **헛된 "완비" 주장 제거** — `batch-state.sh` 가 전건 MERGED queue(산출물 teeth 대상 0건)에서 **FID 디렉터리가 하나도 없어도** `산출물·진행기록 완비` + rc=0 을 냈다. 1건을 실제로 검사한 경우와 **출력이 문자 그대로 같았다**. "완비" 대신 **검사 건수**를 낸다(`0 FID 검사` / `1 FID 검사`). `--gate` 모드도 동일 — 그쪽이 `gh pr create` 를 여는 훅 판정 경로라 파급이 더 크다. **0건 자체는 정상**(갓 시작한 batch·전건 MERGED)이라 에러로 승격하지 않았다 — 차단이 아니라 **가시성**이다.
  - **★ 착수 전 가설을 정정했다** — "무발화 검사 감지를 일반 lib 로" 라는 제안으로 시작했으나 실측 결과 과했다. `emit-context`(스위치 강제) · `check-review-audit`(건수 보고) · `check-review-presence`(*바로 이 문제를 위해 신설된 스크립트*) · `check-regression-ac`(SKIP 사유)가 **전부 이미 해결돼 있었다**. 저장소가 패턴을 인식하고 개별로 처리해 왔고, 일반 lib 는 잘 동작하는 4곳을 억지로 갈아끼우는 리팩터가 됐을 것이다. **확인된 한 곳만** 고쳤다.

- **`queue-set-status.sh` IFS 조작 제거 (#15 동봉)** — semgrep 이 `bash.lang.security.ifs-tampering` 2건을 잡았다. `security-scan.sh` 의 self-check 는 **bash 파일에 위험함수 룰을 적용하지 않아** 놓쳤고, 외부 스캐너 집계에서 `test-security-scan` 의 "자기코드 오탐 0"(AC-R-2)이 깨졌다. 전역 `IFS` 를 바꾸면 그 구간의 모든 분리 동작이 영향을 받고 중간 early-return 시 복원이 누락된다 → 구분자로 감싼 부분문자열 매칭(`case "|${LABELS}|" in *"|${NEW}|"*`)으로 대체. 경계 확인: `DONE`·`IMPL`(부분 문자열)·`"|"`(구분자 자체)·`"PENDING|SKIP"`(다중) 전부 거부.

### Added

- **미완 batch 자동 표면화 (FID 20260828-batch-resume-teeth, #14)** — downstream 실측에서 FR 31건이 `IMPL_DONE` 에서 멈췄고 Phase 3 완료(batch 보안·통합·성능 → batch PR)가 실행되지 않은 채 방치됐다.
  - **조사 결과 새 상태를 만들 일이 아니라 배선 한 칸이었다.** `ACTIVE` 마커는 **이미 재개 키**이고(PR 성공 시 Step D 가 제거) SessionStart 에는 reconcile 주입 경로가 **이미 있는데**, 그 둘을 잇는 batch 인식 판독기만 없었다. `ACTIVE` 를 읽는 곳이 `/start-all` 재호출·PR 게이트뿐이라 **사용자가 먼저 물어야만** 알 수 있었고, `/status`·`reconcile-check` 는 batch 를 **아예 모른다**(batch 참조 0건).
  - **근본 원인은 계층 비대칭이다** — FID 체인은 `chain.yaml` + `## 다음 skill` + 훅 **3중**으로 잠겨 있는데, 그 위를 도는 batch 루프는 `start-all.md` **산문뿐**이라 모델이 N개 FR 을 도는 내내 루프를 놓지 않아야만 성립한다. 세션이 끝나면 이어받을 주체가 없다.
  - `scripts/_internal/batch-resume-check.sh` 신설 + `session-start.sh` 배선. 전건 완료 시 **"Phase 3 완료 미실행"** 을 지목한다 — "완료됐다"가 아니라 **"다음 단계가 안 돌았다"** 를 말해야 재개가 된다. `queue-lib.sh` 재사용(여기서 자기 정규식을 쓰면 #13 이 고친 드리프트가 재발한다).
  - **차단하지 않는다** — 경고도 실패도 아닌 **상태 보고**다. batch 를 의도적으로 중단한 경우도 정상이며 그때 매 세션 에러를 내면 잡음이다.
  - **순서 계약 확인** — SessionStart additionalContext 는 **1536B 프리뷰 예산**과 상대 순서 계약이 있다. `pending 339B`·`reconcile 546B` 변동 없고 상대 순서 유지. `batch-resume` 는 **조건부**라 미완 batch 가 없으면 페이로드가 종전과 동일하다. `CLAUDE.md`·`README.md` 기재 갱신.

- **AC 계약 부재를 verify 관문에서 차단 (FID 20260828-ac-absence-detect, #15)** — `check-ac-format.sh` 는 `emit-context.sh` 에서만 불렸다 — 즉 **decompose 단계 전용**이다. clarify·plan·decompose 를 건너뛰면 emit-context 가 돌 기회 자체가 없어 **AC 파일 부재가 아무 데서도 안 걸린다**. `specifying-ko:19` 는 "emit-context 가 acceptance-criteria.md 실재를 요구한다"를 **승인 우회 차단 근거로 선언**하는데, 그 전제가 상류를 건너뛰면 깨진다.
  - downstream 실측: `acceptance-criteria.md` 가 **아예 없는 FID 3건**이 verify 와 Phase B/C 리뷰를 통과했다. 사후 리뷰에서 리뷰어들이 `screens/*.md`·`requirements.md` 에서 AC 를 **사후 구성**해 판정해야 했다.
  - `run-verification.sh` 에 배선. **차단이다** — AC 는 스프린트 계약이라 없으면 Phase B 가 대조할 기준이 없다. 명령 0건 분기에도 넣었다(`review-audit`·`foundation-manifest` 가 봉합한 **"NO COMMANDS 우회"** 와 같은 구멍). `exit 2`(파일 부재)만 차단하고 `exit 1`(포맷 FAIL)은 emit-context 관할이라 중복 판정하지 않는다.
  - **freework mini-FID 면제** — `templates/freework.md` 가 *"spec.md 없는 경량 트랙"* 이라 직접 선언하므로 `spec.md` 부재 = lifecycle FID 아님. 여기서 FAIL 내면 정당한 자유작업 경로가 통째로 막힌다.
  - **★ grep 배선 테스트가 죽은 코드를 통과시켰다** — `FID_DIR` 이 존재하지 않는 변수라 `set -u` 에서 `unbound variable` 로 터지는데, 배선 테스트(T14·T15)는 grep 이라 그대로 통과했다. **배선 존재와 동작은 다른 질문**이라 실행 검증(T18·T19)을 추가했다.

### Docs

- **도입 검토자용 상세 분석 `docs/architecture.md` 신설 (#11)** — `DESIGN.md` 는 색상·타이포그래피 UI 디자인 시스템이고 `CONTRIBUTING.md` 는 기여 절차, `CLAUDE.md` 는 Claude 용 내부 규약이라 **"이게 어떻게 동작하고 왜 무너지지 않는가"를 설명하는 문서가 없었다**. 장치 4종(훅·실행-근거 게이트·Generator↔Evaluator 분리·파일 기반 상태) · 실행-근거 게이트가 뚫린 4가지 시도와 대응(잘못 고친 2회 포함) · 규모 실측(102 릴리즈·테스트:코드 2.6:1) · **§6 한계 6종**(의도 위조 미차단·기록 진실성 미검사·토큰 비용·큰 FID 정체·repo 밖 산출물 부적합·Claude Code 전용). README 는 카운트·버전이 이미 정확해 통째로 갈지 않고 진입 링크 2곳 + 자기검증 수치 1줄만 더했다.
- **사례 연구 `docs/case-studies/2026-08-27-argus-batch-stall.md` (#12)** — downstream 실사용 데이터(FID 36건·§batch 25건) 사후 분석. 단일 모드 체인은 정상이고 batch 층이 마지막 관문 직전에서 죽는다는 것, 그 사실이 라벨 드리프트로 감춰졌다는 것, 건너뛴 리뷰가 숨기고 있던 결함(Critical 2·Important 12)을 실측으로 규명. **대조군이 결정적이다** — 같은 배치·같은 날·같은 코드베이스에서 리뷰가 실제로 돈 화면만 PASS 였다. 개선안 7종을 도출했고 **이번 릴리즈가 전부 구현한다**.


## [1.80.0] — 2026-08-21

### Added
- **DESIGN.md 패턴 라이브러리 확장 + 소비 배선 (FID 20260821-design-pattern-library, #9)** — `DESIGN.md` 를 색상 토큰표에서 패턴 라이브러리로 확장하고, 화면 생성 경로가 그 섹션을 **실제로 읽도록** 배선한다.
  - **문제는 "패턴 부족" 이 아니라 "채워 놓고 아무도 안 읽는다" 였다** — `phases-design.sh:_design_apply_concept` 가 `ui-reasoning.csv` 에서 §6 레이아웃 패턴·§8 원칙/안티패턴을 **이미 채우는데**, 화면 생성 경로 어디에도 읽으라는 지시가 없었다. `commands/design-screen.md:59` 는 `DESIGN.md §4 준수`(색상·컴포넌트)만 말한다. §9 헤더는 "이 섹션을 AI 에이전트가 직접 읽어 일관된 UI를 생성한다" 고 선언하면서 **정작 그 에이전트에게 말하는 곳이 없었다**. #8 이 고친 "렌더를 아무도 안 본다" 와 같은 클래스라 — **배선이 채움의 전제**다.
  - `templates/DESIGN.md` **`## 6.1 화면 원형` 신설** — 목록·상세·폼·대시보드 × 필수 요소 × 흔한 누락. 모델이 즉흥하던 구간에 기준을 준다. `###` 이 아니라 `##` 인 이유는 DESIGN.md 가 `## N` 평면 번호 체계이고 `U9` 계열이 `^## ` 를 grep 하기 때문.
  - **§7 상태 표현 placeholder → 실값** (v1.7x 부터 `[스켈레톤/스피너/프로그레스]` 로 남아 있던 "후속 FID 이관" 항목). 로딩=300ms 초과 예상 시 스켈레톤(이하 미표시, 국소 동작은 인라인 스피너) · 빈 상태=문구+CTA 필수("데이터 없음" 단독 금지) · 에러=입력 단위 인라인 + 폼 상단 요약 배너 병행. 근거는 `app-interface.csv` 의 `[Feedback] Loading Indicators`·`Error Feedback`. **§7 은 #8 이 만든 `check-screen-quality.sh` 의 `states` 검사와 직접 대응한다** — 검사기가 "정의됐나" 를 묻고 §7 이 "무엇이어야 하나" 에 답한다.
  - **소비 배선 3곳 + 평가 배선 1곳** — `specifying-ko` Step 5.5 · `/design-screen` · `/design-screens` 에 §6~§9 준수 **동일 리터럴 1줄**(215 bytes). 화면 N개면 N배로 곱해지므로 본문 인용 없이 경로·섹션 번호만. `design-reviewer-ko` 에 `DESIGN 준수` 관점 1행 추가 — Critical 칸은 #8 의 품질 관점 4행과 동일하게 비운다(주관 판정으로 `/start-all-auto` 를 세우지 않는다).
  - **★ 무음 사망 지점 2곳을 어서션으로 잠갔다** — ① `_design_apply_concept` 의 접두 리터럴 8종(`- **권장 패턴**:`·`1. **[원칙 1]**`·`- [금지 패턴 1]` …). **§8 의 `[원칙 N]`·`[금지 패턴 N]` 은 placeholder 처럼 보이지만 보존 대상**이라, §7 스캔은 `awk` 로 구간을 한정했다 — 전역 placeholder 스캔이었다면 AC-R-1 과 자기모순으로 **영구 FAIL** 이다. ② `lib.sh:128` 이 grep 하는 색상 표 라벨 9종(기존 `U11`) — 하나라도 바뀌면 `screens/*.html` 색 주입이 `continue` 로 조용히 사라진다. 섹션 제목은 **포함 검사**다(개수 검사면 §6.1 추가로 영구 FAIL).
  - **★ `grep -qF "$lit"` 가 하이픈 접두 리터럴 5종을 옵션으로 오파싱** — `U24.g` 가 RED·GREEN 양쪽에서 **영구 FAIL** 이 되는 결함을 plan-reviewer 가 **실제로 실행해서** 잡았다. plan 자체검토의 "어서션 실행 가능성" 항목을 지금까지 정규식 스코프 관점으로만 봤는데 **grep 인자 파싱도 같은 클래스**다 → `grep -qF -e`.
  - **회귀 방지 — `T1.j`/`T1.k` count-agnostic 화**. 하드코딩 4개 목록을 `QP` 배열 단일 소스로 뽑았다. 5번째 관점을 추가하면 통과는 하는데 라벨이 "품질 관점 4개" 로 남는 회귀인데, **v1.79.0 에서 `test-init-project-enrich.sh` T2.b 를 같은 이유로 고친 자리**라 되풀이를 끊었다.
  - **어서션 이빨 실증** — `code-reviewer-ko` 가 변이 **14종** 을 넣어 표적 어서션이 정확히 1건씩 검출함을 확인(부수 오발 0). 정상 편집 오탐 2종·rc 경계 3종도 검사. bash 3.2.57 + BSD 유틸 실환경.
  - **프로세스 편차(투명성)**: plan 의 "태스크별 receipt + 커밋" 전제가 **RED 태스크에 원리적으로 불가**함이 실측됐다 — `record-task-receipt.sh` 는 `test_command` 가 exit 0 일 때만 기록하는데 RED 는 정의상 rc=1 이다(부수로 `test_command` 의 `;`·`&&` 체인이 whitelist 에도 걸렸다). `SPECOPS_GOVERNANCE_BYPASS` 로 RED 커밋을 억지로 여는 대신 **커밋을 GREEN 완료 + `run-all.sh` 통과 후 1회로 이관**했다.
  - **한계**: 배선은 **산문 지시**다 — 모델이 실제로 §6~§9 를 읽는다는 보장은 없고, 어서션은 "지시가 존재하는가" 만 잠근다. 사후 teeth 는 #8 의 `check-screen-quality.sh` 와 본 변경의 `DESIGN 준수` 관점이 담당하며 이 조합도 완전 강제가 아니다. **§7 빈 상태 기본값은 자산 근거가 없다**(`app-interface.csv` 30행에 empty state 항목 부재 — §7 비고란에 경고 명시). `U24.c` 는 §7 산문에 `[인라인 편집]` 처럼 세 단어로 시작하는 대괄호를 쓰면 오탐한다(placeholder 재유입 차단 목적상 fail-safe 방향, 주석으로 문서화). `templates/DESIGN.md` 가 137→146줄(+28%)이라 화면 생성마다 토큰이 곱해진다 — HTML 스니펫 병기를 기각한 것이 이 비용을 40~80줄 더 늘리지 않은 이유다.

- **화면 품질 게이트 — 정적 계측기 신설 + design-reviewer 품질 관점 4개 (FID 20260820-design-quality-gate, #8)** — `design-reviewer-ko` 의 8관점이 **전부 구조·정합**이라 "구조는 맞물리는데 쓸 수 없는 화면" 이 게이트를 그대로 통과했다. 껍데기 판정(`design-screen.sh --check`)도 마커 grep + 섹션 **제목** 존재만 봐서, 8섹션 제목만 채우면 내용이 부실해도 지나갔다. **모든 게이트가 존재 여부를 볼 뿐 품질을 보지 않았다.**
  - 신규 `scripts/_internal/check-screen-quality.sh` — 화면 쌍(`.md`+`.html`)을 5종으로 계측한다: `states`(empty·loading·error 정의) · `a11y-label`(label 없는 input) · `semantic`(랜드마크) · `token`(색 리터럴 하드코딩) · `microcopy`(무정보 에러 문구).
  - **★ 계측 전용 — 항상 exit 0**. 판정은 리뷰어가 한다. 휴리스틱이라 오탐이 불가피한데 exit code 로 차단하면 **오탐 1건이 배치를 세운다**(`check-ci-status.sh` 동형 계약). 측정과 판단을 분리한 것이 이 설계의 핵심이다.
  - `agents/design-reviewer-ko.md` 에 품질 관점 4행(상태 설계·접근성·디자인 시스템 준수·콘텐츠 품질) 추가. **Critical 칸은 전부 비운다** — 주관 판정으로 `/start-all-auto` 무인 실행을 정지시키지 않는다.
  - **설계 결정 3건 전부 실측 근거**: ① `token` 은 `--이름:` **정의부를 제외**한다 — `screens/login.html` 전수 hex **12건 중 10건이 정의부**라 안 빼면 정상 코드 10건이 위반으로 잡힌다. `rgba()` 등가색도 세지 않는다(카드 그림자·포커스 링은 정당한 사용). ② `states` 는 **영문+한글 둘 다** 인정한다 — 한국어 플러그인인데 영문만 보면 항상 FAIL 이다. ③ 정규식은 `--[A-Za-z0-9-]+:` — `--[a-z-]+:` 였다면 `--gray-100`·`--Color-Primary` 를 놓쳐 정의부 카운트가 0이 되고 **정상 코드가 전부 오탐**한다.
  - 테스트 `test-check-screen-quality.sh` 어서션 12건. **T1.b~f 가 각 검사의 양성·음성을 동시에 요구**한다(`bad`≠`good`) — 한쪽만 보면 구조적 항상통과 어서션이 된다. `T1.g`·`T1.l` 이 "계측 전용" 계약(exit 0 · 무출력 금지)을 잠근다 — 인자 부족·대상 0개에서 침묵하면 **리뷰어가 "위반 없음" 으로 읽는다**(외부 critic 지적).
  - **한계**: 휴리스틱 정적 검사라 렌더 결과는 여전히 보지 않는다. `microcopy` 는 `templates/screen.md` 의 에러 섹션이 **표 형식**인데 스펙이 목록 행 매칭을 정의해 total-miss 가 남아 있다(별도 FID 대기).

## [1.79.0] — 2026-08-20

### Added
- **plan 모드 산출물을 `/init-project` PRD 근거로 편입 (FID 20260820-plan-mode-prd-source, #7)** — `/init-project` 는 PRD 6필드 초안 근거를 3경로(명시 경로 · 브레인스토밍 메모 · 기획 문서 auto-discovery)에서 찾는데, **plan 모드 산출물은 어디에도 닿지 않았다**. plan 은 대화 안에만 있고 파일로 남지 않기 때문이다. 사용자는 방금 plan 으로 정리한 내용을 처음부터 다시 입력해야 했다.
  - **그런데 plan 은 사라지지 않는다** — `ExitPlanMode` 는 **도구 호출**이라 Claude Code transcript(`~/.claude/projects/<cwd-슬러그>/<uuid>.jsonl`)의 `tool_use.input.plan` 에 마크다운 전문이 그대로 남는다. 라인마다 `.timestamp` 도 있다. PreToolUse 훅을 새로 만들 필요가 없었다 — **사후 조회로 충분**했고, R-1/R-2 차단 경로가 걸린 `pretool-governance.sh` 를 건드리지 않았다.
  - 신규 `scripts/_internal/extract-plan-from-transcript.sh` — cwd 슬러그로 프로젝트 transcript 를 찾아 **최신 plan 1건**을 추출한다. stdout=plan 전문(**바이트 동일**, `jq -j`) · stderr=`PLAN-SOURCE`+`PLAN-TITLE` · exit `0` 발견 / `1` 없음 / `2` `jq` 부재.
  - `commands/init-project.md` Phase 0 근거 우선순위가 **3단 → 4단**: `0-a 명시 경로 → 0-b 브레인스토밍 메모 → **0-b2 plan** → 0-c 문서 auto-discovery → 수동`. 발견 시 **y/n 확인 필수**(0-c 와 동일한 무단 소비 금지), `rc≠0` 이면 조용히 0-c 로 하강해 `/init-project` 를 막지 않는다.
  - **★ `grep 'ExitPlanMode'` 는 쓰면 안 된다** — 에이전트 도구 목록 문구(`All tools except Agent, Artifact, ExitPlanMode, ...`)에 걸린다. 본 저장소 실측: grep 은 여러 건 매칭하는데 **실호출은 0건**. `T1.b` 가 "grep 이 1건 이상 매칭한다"와 "추출은 exit 1 이다"를 **동시에** 요구해 grep 구현을 격추한다.
  - **★ 전수 스캔 + `max_by(.ts)`** — mtime 순 첫 발견은 틀릴 수 있다(오래 전 시작해 최근까지 이어진 세션은 mtime 이 최신이나 그 안의 plan 은 더 오래됐을 수 있다). 전수 비용 실측 **40파일/117MB 1초**라 정확도를 택했다. `T1.e` 가 fixture 로 잠근다.
  - **★ 시간 기준은 파일 mtime 이 아니라 plan 라인의 `.timestamp`** — mtime 은 세션 **마지막 활동** 시각이라 stale 판정이 무력해진다. jq 내부 산술(`fromdateiso8601`)이라 `date(1)` 의 BSD/GNU 차이도 타지 않는다. 기본 창 24시간, `SPECOPS_PLAN_MAX_AGE_HOURS` 로 조정.
  - **★ 라인 단위 스트리밍 파싱 — 손상 JSONL 무음 소실 차단**. 초안은 `jq -rs`(슬럽)였는데, 파일 안 **한 줄만 부분 JSON 이어도 전량이 사라지고** `2>/dev/null` 이 오류까지 가려 `rc=1`("plan 없음")으로 위장됐다(재현: 유효 plan 1건 + 잘린 꼬리줄 1개 → rc=1 · stdout 0바이트 · stderr 0바이트). transcript 는 **라이브 append 파일**이라 크래시가 남긴 꼬리줄이 현실적이고, 하필 `/init-project` 가 노리는 plan 이 그 파일 안에 있다. **v1.78.0 `doctor.sh` 가 고친 "손상 JSONL 무음 낙관" 과 같은 클래스의 재발** — `jq -R` + `fromjson? // empty` 로 교체. 부수로 메모리가 파일 크기 비례에서 벗어났다: 194MB 파일 peak RSS **613MB → 2.85MB (215배)**.
  - 테스트 `test-extract-plan-from-transcript.sh` **어서션 15건** — fixture transcript + 가짜 `HOME` 격리(실 `~/.claude` 미접근). 계약 전부 잠금: 바이트 동일·오탐 차단·창 양방향·최신 1건(파일 내/간)·graceful(부재·`jq` 부재·read-only)·빈 plan·env 오입력·손상 JSONL·`HOME` 미설정·배선 상시 잠금.
  - **회귀 1건 동반 수정** — `test-init-project-enrich.sh` T2.b 가 `'(메모 부재|셋 다 부재)'` 로 **경로 개수를 문구째 하드코딩**해, 0-b2 추가로 "셋"→"넷"이 되자 깨졌다. 2→3 때(20260716)도 같은 이유로 고친 자리라 **개수 비의존**(`'(메모 부재|다 부재)'`)으로 바꿔 되풀이를 끊었다. 변이 실증: 문구 삭제→FAIL(격추 유지) · 넷→다섯→PASS(비의존 성공).
  - **한계**: transcript 슬러그 규칙(`/`·`.` → `-`)과 `input.plan` 필드명은 **실측이지 공개 계약이 아니다**. Claude Code 가 바꾸면 추출 0건 → graceful skip(실패 방향 안전)이나 **조용히 죽으므로** 주기 점검 필요. plan 을 확정(`ExitPlanMode` 호출)하지 않고 빠져나온 경우는 복원 불가.

### Fixed
- **릴리즈 push 에 pre-push 재귀 가드 적용 — `run-all` 3회 → 1회 (FID 20260820-release-push-guard, #6)** — 릴리즈 1회가 143 스위트를 **3번** 돌렸다(pre-flight 1 + `git push` 2회가 각각 재발화시킨 pre-push). v1.78.1 실측 **약 22분**.
  - `.githooks/pre-push` 에 재귀 가드가 **이미 있었다** — 그런데 `run-all.sh:10` 의 `export SPECOPS_RUN_ALL=1` 은 **서브프로세스 스코프**라 pre-flight 종료 후 `release.sh` 본체 환경에 남지 않는다. 릴리즈 경로에서만 가드가 무력했다.
  - `git push` **호출부에만** 명령 prefix 로 가드를 켠다. **전역 export 금지** — `release.sh:65` 가 pre-flight 자체를 skip 해 게이트가 전면 상실된다.
  - 가드가 켜지면 pre-push 의 `check-ci-status` 호출부에 도달하지 못하므로 그 신호는 `release.sh` 가 직접 복원한다. **서브셸 `cd` 가 필수** — `check-ci-status.sh` 는 origin 조회를 cwd 기준으로 하고 항상 exit 0 이라, 빠뜨리면 CI 경고가 **무음으로** 사라진다.
  - 훅 본문 **무변경** — 가드를 `check-ci-status` 뒤로 옮기는 안은 배치 계약("면제 4종 뒤 — 앞에 두면 비-specops repo 에서 gh 를 부르는 월권")을 위반한다. `git push --no-verify` 안은 릴리즈 경로에서 게이트 배선을 영구 절단해 기각했다.
  - `test-release.sh` **T20.a~d** 정적 검사 신설(push 는 원격 필요로 실행 검증 불가). **변이 6종 전부 격추 실증** — prefix 제거→T20.a · 전역 export→T20.b · CI 체크 제거→T20.c · 러너 분기→T20.d · trailing 주석 export→T20.b · 서브셸 cd 제거→T20.c.
  - **★ `T20.b` 정규화 두 번의 교훈** — ① 초안 정규식이 `T20.a` 가 요구하는 prefix 줄을 매칭해 **GREEN 을 자기격추**했다(RED 단계에선 안 보이는 결함, plan-reviewer 가 격추). ② 줄 끝 앵커만으로는 `export SPECOPS_RUN_ALL=1  # 가드` 처럼 **주석 붙은** 전역 export 를 놓쳤다(code-reviewer 가 격추). `T11.a` 는 `RELEASE_PREFLIGHT_CMD=true` 탓에 이 회귀에 **발화하지 않으므로 T20.b 가 유일 teeth** 다 — 주석에도 명기했다.
  - **회귀 1건 동반 수정** — `propagation-matrix.jsonl` 에 id 를 추가하면서 `test-propagation.sh` P1 의 **하드코딩 allowlist** 갱신을 놓쳐 `run-all` 이 FAIL 했다. `check-propagation.sh` 는 `PASS (164 edges)` 로 통과했기 때문에 **edge 등록만 봐서는 드러나지 않는다** — 두 검사가 서로 다른 것을 본다.
  - **알려진 한계(범위 밖)**: clean 트리에서 `test-release.sh` 를 **단독** 실행하면 `T10.b` 가 실제 pre-flight → `run-all` 중첩을 일으켜 10분을 넘긴다. `run-all` 경유는 가드로 즉시 통과하므로 **CI·pre-push 무영향**이고, `T10.b` 의 기존 성질이라 본 FID 에서 손대지 않았다. 공교롭게 본 수정과 같은 클래스다.

## [1.78.1] — 2026-08-20

### Changed
- **README 재작성 — 정의·사용법·lifecycle 중심 (docs-only)** — 기존 README 는 자산 트리·거버넌스 세부에 비해 **"specops-ko 가 무엇인가"** 를 설명하는 층이 얇았다. 정의 3줄(자율 chain · 파일이 기억한다 · 주장은 증거로만)을 앞세우고 `설치 → 빠른 시작 → 진입로 결정 트리 → Lifecycle → 산출물 → 거버넌스 엔진 → 운영 슬래시 → 자산 구조 → 개발·테스트 → 트러블슈팅` 순으로 재편했다. 내부 규약 상세(chain SoT · 분기 마커 · frontmatter 필수 필드 · design-first 대칭)는 중복 서술 대신 `CLAUDE.md` 참조로 위임. **274 → 221줄**.
  - **lifecycle 단계 표기를 `영문(한글)` 로 통일** — `analyzing-ko (분석)` · `specifying-ko (명세)` · `clarifying-ko (명확화)` · `planning-ko (계획)` · `decomposing-ko (분해)` · `implementing-ko (구현)` · `verifying-evidence-ko (검증)` · `security-review-ko (보안)` · `integration-test-ko (통합 테스트)` · `performance-test-ko (성능 테스트)` · `finishing-a-development-branch-ko (브랜치 정리)`. 리뷰어 3종(`plan-reviewer-ko` 플랜 리뷰 · `spec-reviewer-ko` 스펙 준수 리뷰 · `code-reviewer-ko` 코드 품질·보안 리뷰)과 HARD GATE 설명 줄도 같은 표기로 맞췄다.
  - **★ README 는 산문이 아니라 계약이다** — 1차 간소화에서 앵커를 지웠다가 pre-push 가 **3 스위트를 격추**했다. `test-readme-entry-tree`(AC-6b~6f: `check-foundation-merged`/머지 후 · `foundation-baseline` · `foundation-shell` · `init-batch-queue` · `[공통]`) · `test-session-start-order`(T-ord.g `조립 순서`) · `test-doc-stamp-sync`(AC-2 `## 거버넌스 엔진` 섹션 내 `PreToolUse`). 문서를 되돌리지 않고 **앵커만 최소 복원**했다 — 진입로 절 "공통부·일괄 진입 주의" 5줄 + 거버넌스 절 제목 원복 + SessionStart 조립 순서 1문장. 간소화가 문서 품질 문제가 아니라 **계약 위반**으로 잡힌다는 것을 실증한 사례.
  - 헤더의 `spec → clarify → plan → …` 체인만 **영문 원문 유지** — `test-readme-entry-tree` AC-R-1 이 그 문자열을 정규식으로 잠근다. 괄호를 끼우면 격추되므로 바로 아래에 한글 미러 줄을 붙여 표기 요구를 충족했다.
  - 기계검증 불변식 5종 보존: 헤더 `(vX.Y.Z)` **첫 매치** · footer `최신: vX.Y.Z (날짜)` shape(`release.sh` sed 가 `grep -q` 가드라 shape 이 깨지면 **무음 skip**) · `SKILL.md × 30` · `templates ← 34건` · `agents ← 8건`.

## [1.78.0] — 2026-08-15

### Added
- **doctor 무음 실패 감지 `stale` 항목 (FID 20260815-doctor-stale-detect, #5)** — `doctor` 는 설치·정합만 보고 **"얼마나 방치됐나"** 축이 없었다. 직전 FID(#4)에서 SessionStart pending 안내가 약 1개월간 미수신됐는데 **어떤 게이트도 잡지 못한** 것이 직접 동기다. 코드 버그가 아니라 *동작하는데 아무도 안 읽는 상태*였고, 이 클래스를 보는 층이 0곳이었다. checks **5 → 6**.
  - **3지표 종합 1행** — pending 적체(최고령 **>7일**) · freelog 정체(**>14일 AND 그 이후 커밋 ≥1**) · 우회 상시화(최근 30일 `BYPASS-ENV` **≥3건**). 하나라도 초과 → `warn`, 소스 전부 부재 → `unknown`, 전부 미만 → `ok`.
  - **★ freelog 는 커밋 조건이 필수다** — `>14일` 만으로 판정하면 **휴지기를 정체로 오탐**한다. 그 이후 커밋이 1건 이상일 때만 경고한다(AC-3). 커밋 수는 repo 활동의 **대리 지표**이므로 커밋 없는 자유작업은 미탐(한계).
  - **★ 손상 JSONL 에 무음 낙관 금지** — `jq -rs`(전체 슬럽)는 마지막 1줄만 깨져도 **전량이 사라져** `byp=0` → `ok "적체 없음"` 이 된다(Phase C probeB: 유효 우회 3건 + 손상 1줄 → `ok`). friction-log·pending-capture 는 **훅이 append** 하는 파일이라 중단된 append 로 부분 라인이 현실적으로 생긴다. 파일당 jq 1회(`-Rsr` + 내부 `split`) 라인 단위 파싱으로 바꾸고, 버려진 줄이 있으면 `ok` 대신 **`unknown "부분 판정 불가 (손상 라인 N줄)"`** 로 강등한다. 무음 실패 감지기가 **자기 입력 손상에 무음이던** 결함이다.
  - **판독 실패도 강등** — `-s` 는 통과하는데 읽을 수 없는 파일(권한·디렉토리)이면 `grep -c` 도 빈값 → `bad=0` → "적체 없음". `case ''|0) x=1` 로 최소 1 강등(구현자 자체 발견, 같은 무음 낙관 클래스).
  - **`--since` 앵커 결정성** — `git log --since=YYYY-MM-DD` 의 approxidate 는 자정이 아니라 **실행 시각-of-day** 앵커다(실측: 01:29 커밋이 14:39 실행 시 0건). 이미 계산된 **UTC 자정 `$iso`** 를 재사용해 결정적으로 만들었다.
  - **NFR — 파일당 스폰 1회 유지**: 45파일 실측 **0.37s**(main 기준선 0.36s, 예산 2s). 파이프 2회 0.67s · `$(...)` 캡처 후 재투입 0.73s 로 **캡처가 더 느리다**(파이프 동시 실행의 직렬화) — advisor 제안을 실측이 뒤집은 지점.
  - `exit 0` · read-only 계약 불변. `_add` 4필드·`--json schema_version:1` 구조 불변(원소 수만 5→6). `checks 5→6` 하드코딩 **8곳 승계**(`test-doctor.sh` 6곳 + `test-init-finalize.sh` F9·F-doc2). `commands/doctor.md` 3곳(frontmatter description·`specops_version`·항목 표).
  - 테스트 `test-doctor.sh` **31 → 48**(T-stale.a~q 17건), `test-init-finalize.sh` 13 → **14**.

  - **★ 변이 실험 — 락 4건 전부 격추 실증**. 이 FID 에서 잡힌 결함은 전부 **"테스트는 있는데 그 값을 잠그지 않는다"** 는 같은 클래스였다:

    | 결함 | 발견 | 변이 | 격추 |
    |---|---|---|---|
    | 우회 30일 창 미적용(항상 warn) | clarify F-1 | 창 없는 필터 복귀 | `T-stale.h` |
    | freelog 임계 무테스트 | Phase B 1차 | `-gt 14` → `-gt 0` | `T-stale.m` 단독 (**변이 전 43건 전부 생존**) |
    | 손상 JSONL 무음 낙관 | Phase C 1차 | `jq -rs` 슬럽 복귀 | `T-stale.o` 단독 |
    | jq 판독 실패 fallback 무테스트 | Phase C 2차 | `pend_bad=1` → `=0` | `T-stale.q` 단독 (`T-stale.p` 는 생존 — fallback 미도달 전제 실증) |

    원복은 전부 `cp` 백업(`git checkout` 은 미커밋 작업 파괴). 어서션 **개수**가 아니라 **변이 생존 여부**가 계약의 실질임을 4번 반복 확인했다.

  - **★ `LITE-STRICT-GUARD` 오탐이 만든 승격이 결함 3건을 걸렀다** — `/maintain-lite` 로 시작했으나 `risk-profile.sh` 가 신호 `destructive_fs`(실체는 테스트의 `rm -rf` 샌드박스 정리)로 rc=3 을 내 정식 plan 승격이 강제됐다. **신호 자체는 오탐**이었지만 그 승격 덕에 clarify 가 F-1 을, plan-reviewer 가 Critical(5-하드코딩 **5곳 누락**)을, 구현자가 F9(8번째 지점 `test-init-finalize.sh:204`)를 찾았다. 가드의 가치가 신호 정확도만으로 평가되지 않음을 보여준다.
  - **한계** — ① 임계 7/14/30/3 은 1건에서 역산, 통계적 근거 없음(오탐 피해 상한은 경고 1줄) ② `T-stale.q` 디렉토리 픽스처는 "디렉토리가 `-s` 에 size>0" 전제에 의존(APFS·ext4 실측, POSIX 보장 아님 — **CI Ubuntu 통과로 Linux 확인**) ③ `T-stale.m` UTC 자정 flake 창(수십 ms, 재실행 해소) ④ `jq` 미설치 분기 무테스트(PATH 교체 회피 관행) ⑤ 멀티바이트 손상·초대형 파일·심볼릭 링크 friction-log 미프로브.
  - **후속 과제** — ① **R-1 통합 경로 결함 의심**: `_verify_exec_evidence` 가 1·2인자 모두 `rc=0`, `detect_fid`·②앵커 정상인데 **PreToolUse 통합만 deny**(재현 절차는 `.specops/20260815-doctor-stale-detect/evidence.md §9`). 본 FID 커밋·PR 에서 우회 2회를 강요했다 ② 러너 앵커가 **파이프 형태**(`| tail`)를 인식하지 못함 — 2개 FID 연속 관측 ③ `scan-enrich-placeholders.sh` 의 꺾쇠 훅 태그 오탐 — **2회째 재발**.

## [1.77.0] — 2026-08-15

### Fixed
- **SessionStart 페이로드 조립 순서 재배치 (FID 20260814-sessionstart-payload-order, #4)** — `additionalContext` 가 harness 인라인 한도를 넘어 **선두 2KB(38줄)만 노출**되고 나머지가 파일로 밀리는데, 행동 지시 블록이 뒤쪽에 누적돼 **모델에 도달하지 못했다**. `session_context` 단일 누적 변수를 `anchor_block`/`pending_out`/`reconcile_out`/`rehydrate_out`/`meta_block` **5변수로 분리**해 확정 순서로 1회 결합한다.
  - **실측 동기**: `<freecomment-pending>` 이 **250번째 줄**(byte 12,671)에 있어, 자유작업 12건이 **2026-07-23~08-10 약 1개월간** `freelog.md` 로 승격되지 않았다. 훅은 매 세션 `미기록 자유작업 12건` 을 정확히 계산해 주입했으나 **한 번도 수신되지 않았다**. `freelog.md` 마지막 기록 `20260712` ↔ pending 최초 적체 `20260723` 의 시점 일치가 이를 뒷받침한다.
  - **★ 구조적 원인은 개별 블록이 아니라 누적이다** — 블록이 `#137 → #142 → freecomment → #228 → #246` 로 **뒤에 하나씩 append 되며** 늘었고, 각 PR 은 자기 블록만 검증했다. **누적 크기·순서를 본 PR 이 없다.** 기존 테스트 6종도 블록 **존재**만 단언해 이 회귀를 구조적으로 못 잡았다.
  - **★ 정렬 기준은 "행동 지시 먼저"가 아니라 "행동 지시 먼저 + 작은 것 먼저"** — `rehydrate` 단독이 **7,807 B**(전체의 49%)라 앞에 두면 뒤를 전부 밀어낸다. 확정 순서 `anchor → pending → reconcile → 메타 본문 → rehydrate`. rehydrate 를 최후미로 보내 **메타 skill 본문 선두 ~1.4KB 가 프리뷰에 노출**되도록 했다(clarify Q1 — 참조 데이터라 절단 손실이 가장 작다).
  - **오프셋 실측**: `freecomment-pending` **16,303 B → 339 B**, `session-progress-reconcile` **15,757 B → 546 B** (상한 1,536 B = 관측 프리뷰 2,048 B 의 75%, 임계 비공개에 대한 25% 마진).
  - **기존 5개 블록은 바이트 단위 불변** — 구·신 훅 출력을 블록별로 diff 해 `EXTREMELY_IMPORTANT`·`rehydrate`·`reconcile`·`pending` 전량 **IDENTICAL** 확인. 신뢰경계 펜스(`325db5c`)·escape 경로 원문 그대로, 조립 방식만 변경. 출력 스키마·훅 비활성 `{}` 경로도 무변경.
  - **`scripts/tests/test-session-start-order.sh` 신설** (T-ord.a~h, 8건) — 순서·오프셋 계약 + **문서 3곳 계약 기재**(CLAUDE.md·README.md·context-resets-ko)까지 잠근다. 문서 어서션(T-ord.f~h)은 당초 T3 의 raw grep `test_command` 였으나 `record-task-receipt.sh` whitelist(`bash scripts/*.sh` 계열)를 구조적으로 통과 못 해, **우회 명령으로 바꾸는 대신 회귀 어서션으로 승격**했다. run-all 스위트 **142 → 143**(glob 자동 편입).
  - **NFR-4 실측** — 구본 1,689.3 ms/회 vs 신본 **1,669.4 ms/회**, 외부 호출·subshell **16 → 16**(추가 프로세스 기동 0). 측정 함정 기록: 구본을 다른 경로에 두고 재면 `PLUGIN_ROOT` 가 어긋나 조기 종료해 **28.8 ms(58배 차)** 라는 허위 회귀가 나온다 — 반드시 동일 경로에서 잰다.
  - **한계 — harness 절단 임계는 비공개 관측치**다. 프리뷰 2,048 B·11.3KB 초과 판정은 실세션 관측이며 공식 계약이 아니다. 그래서 계약을 "N바이트 이하"가 아니라 **"행동 지시를 가능한 한 앞에"** 로 잡았다. **절단 동작 자체는 검증하지 못했다.**
  - **한계 — 앵커의 대체 효과는 자동 검증 불가**: `<specops-ko-anchor>` 가 메타 본문의 "최우선 지시" 신호를 대신한다는 가정은 정성 관찰로만 확인 가능하다. **릴리즈 후 첫 세션의 육안 확인이 실질 수용 테스트**다(1.76.0 의 *"효과 관측은 릴리즈를 기다린다"* 와 동일 구조 — 훅은 설치 캐시에서 실행된다).
  - **한계 — clarify 가 AC 를 뒤집을 때의 처리**: 블록 4·5 순서 결정이 AC-1 원안과 충돌했으나 append-only 규약상 AC 본문을 고치지 않고 **AC-6 신설 + 파일 말미 정정 고지(supersede)** 로 처리했다. 리뷰어 dispatch 프롬프트에 이 사실을 명시해야 원문만 보고 오판하지 않는다.
  - **후속 과제** — ① `scan-enrich-placeholders.sh` 가 꺾쇠 훅 블록 태그를 템플릿 placeholder 로 **오탐**(본 FID 산출물이 `check-maintain-baseline` FAIL 을 맞음, 표기 변경으로 우회) ② `_verify_exec_evidence` 의 러너 호출 감지가 **파이프 형태**를 포함하는지 점검(장시간 러너의 백그라운드+Read 경로 안내와 실제 감지 로직 대조).

## [1.76.0] — 2026-08-14

### Fixed
- **posttool 마찰 기록에 `scope_class` 배선 (FID 20260814-friction-scope-posttool, #3)** — `posttool-governance.sh:72` 이 `log_friction` 을 **5 인자로** 호출해 6번째 선택 인자를 넘기지 않았고, 빈 값이면 필드 자체가 생략되므로(`governance-lib.sh:793`) posttool 산출 **R-1/R-2 warn 계열 전량이 집계에서 영구 `판정불가`** 로 떨어졌다. 직전 `#2` 가 pretool 절반만 배선하고 남긴 미완 부분이다.
  - **실측 동기**: 267행 중 `scope_class` 보유 **1행**. R-1 `188행 = block 86 + warn 102`, R-2 `31행 = block 13 + warn 18` — warn 계열은 구조적으로 영구 판정불가였다.
  - **`_audit_scope_class <rule_id>` 신설** (`governance-lib.sh:611`) — 범위는 `is_docs_only_audit_scope` 와 **동일**(R-1 `HEAD~1..HEAD` / R-2 `base...HEAD`), 분류는 `_files_all_docs` 재사용으로 **"분류 클래스 ≡ 면제 클래스"** 불변식(`:481`)을 보존한다. `_commit_scope_class` 재사용은 **금지** — posttool 은 액션 **후** 발화라 `git diff --cached` 가 비어 `empty` 로 조용히 오분류된다. 같은 개념(커밋 범위)이라도 **발화 시점이 다르면 별도 함수**다.
  - **★ posttool 기여분에 `docs-only` 는 구조적으로 나오지 않는다** — `posttool-governance.sh:56` 이 면제 시 **기록 자체를 하지 않으므로** posttool 행은 정의상 docs-only 가 아니고 실제 산출값은 `code`·`empty`·판정불가 **3종**이다. 결함이 아니라 설계 사실이라 정의부·배선부 주석과 `CLAUDE.md` 에 명시했다. 반환값에 `docs-only` 를 남긴 것은 직접 호출·향후 재사용을 위한 **계약 대칭**이다.
  - **판정불가(무출력) ↔ `empty` 축 분리 유지** — git 실패(`HEAD~1` 부재)·base 미탐지·미지원 rule_id 는 **무출력**, git 성공 + 빈 목록은 `empty`. `_commit_scope_class` 와 동형.
  - **`log_friction` 시그니처 무변경** — 6번째 선택 인자만 채웠다. 기존 5-인자 호출부(`stop:60`·`pretool:391,398`·`:195`)는 종전과 **byte-identical** 레코드를 산출한다(blast radius 0).
  - **★ 결속 원장의 `must_match` 는 심볼명 평문이면 잠금이 무음 사망한다** — AC-6 이 **요구한** 주석(`posttool-governance.sh:73`)이 같은 심볼을 포함해, 호출부(`:76`)만 지우는 변이가 `PROPAGATION: PASS (160 edges)` 로 **생존**했다(실측). call-site 앵커 `\$\(_audit_scope_class` 로 좁혀 FAIL 재현을 확보했다. plan 확정 텍스트를 구현 중 정정한 유일 편차이며 Phase B 가 승인했다.
  - `propagation-matrix.jsonl` `friction-scope-class` edge **156 → 160**. 테스트 `test-lib` 96 → **104**(`T-acls.a~h`) · `test-hooks` 9 → **10**(`T8.g` — 훅↔lib↔JSONL↔git 4단 경계 통합).
  - **한계 — NFR-2 경로별 갈림(수용)**: 비위반 경로(posttool 발화의 대다수) median 델타 **+0~2ms ≤ 5ms** 로 통과하나, **위반-기록 경로는 191→209ms(+17~18ms)** 로 예산을 ~13ms 초과한다. 초과분은 subshell fork + `git diff` 1회이며 분류를 계산하는 이상 회피 불가하고, 해당 경로는 사용자가 방금 `git commit`(100ms+)을 실행한 직후라 체감되지 않는다. 사용자 판정으로 **PASS + 한계 명시**를 채택했다. 후속: NFR 문면을 경로별로 분리.
  - **한계 — 소급 불가**: 기존 266행은 원본 커밋 범위가 로그에 없어 재분류 수단이 없다.
  - **★ 효과 관측은 릴리즈를 기다린다** — 훅은 repo 작업트리가 아니라 **설치된 플러그인 캐시**(`~/.claude/plugins/cache/.../hooks/`)에서 실행된다. 머지 직후 관측에서 posttool warn 행이 여전히 `<필드부재>` 였던 것이 이 때문이다(T2 커밋 08:29 이후인 08:30·08:41 행도 부재). 이 repo 는 자기 자신이 플러그인이라 **모든 훅 변경의 효과 확인이 1 릴리즈만큼 지연**된다 — `#2` 의 pretool 절반이 "가동 후 실데이터 0건" 이었던 것도 같은 구조로 보인다.

## [1.75.0] — 2026-08-13

### Added
- **friction-log 커밋 범위 분류 (FID 20260813-friction-staged-record, #2)** — 마찰 기록에 `scope_class`(`docs-only|code|empty`)를 남기고 `gbrain-friction` 이 규칙별 **4열**(`docs-only`·`code`·`empty`·`판정불가`)로 집계한다. 직전 FID(`20260813-r1-docs-only-scope`)가 *"block 77건 중 결함 유래 N건"* 을 끝내 세지 못하고 성공지표를 **"효과 미측정"** 으로 남긴 것이 직접 동기다.
  - **★ 산출물은 필드가 아니라 분류 출력이다** — 실측상 `evidence_snippet`·`principle`·`transcript_offset` 은 **기록되지만 아무도 읽지 않는다**(`gbrain-friction.sh:62-63` 이 읽는 것은 4개 필드뿐). 필드만 추가하면 **네 번째 write-only 필드**가 되어 고치려던 실패 모드를 재생산한다. 그래서 계약(AC)을 JSONL 키가 아니라 **가시 출력**에 걸었다(advisor 협의로 산출물 정의를 뒤집음).
  - **`log_friction`·`log_friction_sev` 둘 다 선택적 마지막 인자** — 교체가 아니다. `log_friction:713-718` 은 fid 가 비면 **전역 파일로 fallback** 하는데 `_sev:754` 는 드랍하고, dedup 도 전자는 severity 무관·후자는 block 한정이다. 교체했다면 감사 테스트 4곳(`test-pretool.sh:482`·`504`·`509`·`535`)이 회귀했을 것이다(plan-reviewer 1회차 적발). 기존 5개 호출부는 무수정 — blast radius 0.
  - **`판정불가` ↔ `empty` 를 뭉개지 않는다** — 필드 부재(구 레코드)는 `// "unknown"`, 빈 커밋범위는 `"empty"`. `_commit_scope_class` 는 두 `git diff` 가 **모두 rc≠0** 이면 무출력해 필드를 생략시킨다(판정 불가와 빈 범위의 구별).
  - **계측 지점 3곳** — `BYPASS-ENV` `:59`(세션-env)·`:165`(인라인) + R-1/R-2 block `:233`. block 은 `:191` 이 이미 계산한 목록을 재사용해 **deny 핫패스 git 재실행 0**(실측 141→142ms). `R-1-SCOPE`(`:193`)는 값이 항상 `docs-only` 라 제외(clarify D2).
  - **`:165` 인라인 경로가 지배 데이터원** — `T-fsc.a~c` 는 env 를 세팅해 `:56` 에서 단락되므로 그 배선을 **잠그지 못한다**. `T-fsc.g` 가 유일한 락이다(plan-reviewer 2회차 적발 — 없었으면 워커가 빠뜨려도 전 스위트 green).
  - **리뷰가 잡은 결함 3건** — ① plan RED 예측 오류(구현자가 `git show` 로 반증) ② **로케일 의존 결함**: plan 지시 `(.ts // "?")` 가 awk `$4 > last[r]` 문자열 비교와 결합해 `LC_ALL=C` 에서 `최근` 열을 붕괴시켰다(`"?"`=0x3F > `"2"`=0x32). **UTF-8 개발 환경에선 가려지고 CI 에서만 터지는** 종류라 `$4 != "?"` 가드 + `T28`(LC_ALL=C 고정)로 봉합 ③ **stale 전역**: `is_docs_only_change` 이른 반환이 `_SPECOPS_SCOPE_FILES` 를 리셋하지 않아, batch 게이트가 먼저 채운 목록을 deny 경로가 분류했다(실측 `code` — 진실은 `empty`). working-tree 가 all-docs 면 block 에 `docs-only` 가 출현해 **AC-3 이 세운 "구조적 불가" 이상신호 축을 자기오염**시킨다. 진입부 1줄 리셋 + `T-cls.p`(변이 격추 확인).
  - 테스트 `test-lib` 79→**96** · `test-pretool` 119→**126** · `test-gbrain-friction` 25→**29** · propagation 150→**156 edges** · run-all **142/142**.
  - **한계**: **효과는 아직 0** 이다 — 실 로그 259행이 전부 `판정불가`(배선 이전 레코드)다. 분류가 쌓이는지는 **향후 세션에서만** 확인된다. 소급 분류는 원리적으로 불가하고, block 지점은 도달 조건상 `code|empty` **2분류로 축퇴**하므로 실질 변량은 `BYPASS-ENV` 축에 있다. `plan-reviewer` 2회차 FAIL(Critical 0) 후 **cap 소진으로 3회차 없이 진행**(사용자 결정) — Phase B/C 가 게이트했다. `semgrep`·`gitleaks` 미설치. Linux 미검증.
  - **후속 이관 2건**: `:236` call-site 주석(빈 전역이 강제 `empty` 가 되는 trade-off) · propagation `gbrain-friction` edge 를 `// "unknown"` 리터럴로 조이기.

## [1.74.0] — 2026-08-13

### Fixed
- **R-1 docs-only 면제 스코프 — 커밋 명령 인지 (FID 20260813-r1-docs-only-scope, #1)** — R-1 커밋 게이트의 docs-only 면제가 **실제 커밋될 파일**이 아니라 **작업트리 전체**(`git diff HEAD`)를 봐서, 문서만 staged 해 커밋해도 작업트리에 남은 코드 수정 때문에 차단됐다. 실측: friction-log R-1 **block 77회 / 38 FID**, BYPASS 사유 16건 중 **13건이 "코드 변경 0"**(gbrain 학습 적재·CHANGELOG·`specops_version` 스탬프 등).
  - **현행 동작은 버그가 아니라 의도된 과잉 근사였다** — `test-lib.sh:122` `T-docs.d` 가 `git commit -am` 우회 방어로 명시 잠금한다. 명령을 모르면 unstaged 코드가 커밋될지 알 수 없기 때문이다. 본 FID 는 훅이 **이미 보유한** 커밋 명령 원문(`pretool-governance.sh:27`)을 스코프 결정에 넘겨 그 불확실성 자체를 제거한다.
  - **선택적 인자 = 회귀 안전망**. `is_docs_only_change [<commit_cmd>]` 는 **인자 없이 부르면 현행과 완전히 동일**하다 — batch 게이트(`:112`)·posttool `is_docs_only_audit_scope`·기존 테스트 `T-docs.a~q` 가 전부 **무수정**이다. 배선은 `:181`(R-1 본체) 한 곳뿐.
  - **화이트리스트 방향** — `#255` 가 "이름 나열" 접근의 **3회 반복 실패**를 기록한다. 위험 형태를 나열하면 나열 밖이 뚫리므로, 안전 형태(C1~C6)만 통과시켜 나열 밖이 전부 **보수(false-block) 방향**으로만 틀리게 했다. `-am`·compound·경로인자·`--amend`·`git -c`·env 접두·명령치환·미분류는 전부 현행 스코프 폴백.
  - **`-F -` heredoc 포함** — friction-log 실측상 이 repo 주력 커밋 형태(`git commit -q -F - <<'EOF'` 11건)다. 메시지 입력이라 파일 범위와 무관해 안전하다(AC-7).
  - **Phase B 가 이 FID 가 새로 연 구멍을 잡았다** — 첫 줄 절단(`${s%%$'\n'*}`)이 잔여 줄을 무검증 폐기해, 첫 줄만 안전 형태면 둘째 줄부터 무엇이든 통과했다(`git commit -m 'docs'` ⏎ `git add -A` ⏎ `git commit -am 'code'` → 축소 승인). **구코드는 deny 하던 경로**임을 e2e 반사실 대조로 확정. 멀티라인 전면 거부는 AC-7 을 깨뜨려 불가하므로, 잔여 줄이 **heredoc 종결자로만 설명되는지** 검사하도록 봉합했다.
  - **Phase C Important 2건 흡수** — ① `$(`·백틱 토큰이 `skip` 으로 무검사 소비되던 구조적 비일관(`_strip_quoted_strings` 는 그 토큰을 "실제 실행됨 → 판정 보존" 목적으로 일부러 남기는데 skip 이 무력화). 치환은 커밋 **前** 실행이라 `-m "$(ga)"` 한 형태로도 파싱 시점 ≠ 커밋 시점 staged 가 성립한다. ② `:483` 주석이 실측과 불일치 — **본 FID 의 결함 뿌리가 틀린 주석**("working-tree 가 곧 커밋 범위")이었으므로 검증 없는 안전 주장을 새로 남기지 않는다.
  - **효과 측정 수단 신설** — 스코프 축소가 열어준 경우 `rule_id: R-1-SCOPE` / `severity: info` 1행 기록. `gbrain-friction` 이 `rule_id` 로 그룹핑하고 증류 후보를 `blocks>=임계` 로 거르므로 **R-1 통계는 불변**이다(AC-9 가 before=after 로 잠금).
  - 테스트 `test-lib` 44→**79** · `test-pretool` 114→**119** · `test-gbrain-friction` 24→**25** · propagation 145→**150 edges** · 변이 M1 격추 3건(+부수 5건) · run-all **142/142** · 성능 NFR-2 median **26→26ms(델타 0)**.
  - **한계**: **효과 미측정** — 기존 77 block 중 본 결함 유래를 friction-log 에 staged 목록이 없어 사후 산정할 수 없다. 표적은 `.md` 클래스 **약 8건**이고 `.specops` 클래스 약 5건은 gitignore 전환으로 이미 소멸했다 — 확인은 **향후 세션에서만** 가능하다. 의도적 잔존: compound false-block · wrapper-class(`sh -c`)는 F-3 WON'T-FIX. `semgrep`·`gitleaks` 미설치라 보안은 self-check 층만. Linux 미검증(bash 3.2.57 macOS 실측).
  - **후속 이관 3건**: 릴리즈 경로 면제(`release.sh` pre-flight 가 `run-all` 을 이미 도는데 R-1 이 또 막는 이중 검증) · friction-log staged 목록 기록(오탐 사후 산정 가능화) · Phase C Minor 3건.

- **llm-eval `TIMEOUT` 120→**300**초 · `MAX_TURNS` 는 **4 유지**(12 상향 시도 후 실측 반증·되돌림) (20260813)** — 17건 실행에서 **8건 FAIL** 이 났고, 그중 6건이 `TIMEOUT` 이었다.
  - **TIMEOUT 이 판정 실패를 가리고 있었다** — 같은 fixture 6건이 `120s=TIMEOUT` → `300s=판정 결과 노출`(`got=none`) 로 뒤집혔다. 120초는 조사 도중 끊어 원인을 감추는 층이었다. **이 상향은 유효하며 유지한다.**
  - **`MAX_TURNS` 4→12 는 틀렸고 되돌렸다.** `error_max_turns` 를 "턴이 모자라다"로 읽었는데 transcript 가 정반대를 보여줬다. `--allowedTools Skill` 은 배타 제한이 아니라 "권한 프롬프트 면제 목록"이라(deny 는 `--disallowedTools`) 모델이 `Bash`·`Read`·**`Write`** 를 자유롭게 쓴다. 턴 여유를 주면 Skill 을 부르는 대신 **직접 다 만들어버린다**.
    - `maint-1` @4턴 — `ls`/`find` → `Read slug.sh` → `git log`+버그 재현 → `locale` 대조 → `error_max_turns`(num_turns=5), **Skill 0회** ($0.41)
    - `new-1` @12턴 — 조사 3턴 후 *"TDD 순서. 테스트 먼저 (RED)."* → `Write` ×8 + `npm test` 로 CLI 를 완성. **Skill 0회**, thinking·text 에 `specops`/`skill` 언급 **0회**, `num_turns=14` ($1.41 — 3.4배)
    - **`new-1` 은 4턴에서 PASS 하던 fixture 다.** 즉 낮은 `max_turns` 가 **우연히 강제력으로 작동**하고 있었다. 통과율을 knob 으로 올리려던 시도가 통과율을 떨어뜨렸다.
  - **드러난 더 큰 문제 — 이 eval 은 신호 감지율을 재고 있지 않다.** 재는 것은 *"시간이 없을 때 모델이 뭘 먼저 하나"* 에 가깝다. 실사용은 턴 무제한이므로 **실제 감지율은 이 숫자보다 낮다**. 베이스라인 `PASS=10 FAIL=0` 도 같은 착시일 수 있어 신뢰 근거가 못 된다. 메타 skill 은 주입까지는 정상 도달한다(SessionStart 훅 확인) — 모델이 받고도 **인식하지 않는다**. 후속 FID 대상이며, 착수 전에 **eval 이 무엇을 측정할 것인지부터 재정의**해야 한다.
  - **조사를 `--disallowedTools` 로 봉쇄하지 않는다** — "볼 게 없으니 Skill 부름"이 되어 실사용에서 더 멀어진다.
  - **한계**: 되돌린 뒤 **실 eval 재검증 미실시**(토큰 비용). 회귀는 stub 기반 `test-llm-eval` 40건 + 관련 4스위트 PASS 로만 확인했다. `MAX_TURNS` 반증 근거는 fixture **2건 표본**(`new-1` 역전 + `maint-1` transcript)이다 — 전수 확인은 안 했고, 방향성 증거로만 쓴다. 비용 주석 실측 반영(`~$0.5` → `~$0.9`/fixture, 재시도 cap=1 포함).

## [1.73.0] — 2026-08-13

### Fixed
- **`/init-project` repo 루트 가드 — worktree 오탐·subdir 자동 복구 (FID 20260811-init-cwd-root-guard)** — `_check_git` 이 `[ -d .git ]` 로 판정해 **git worktree 루트**(`.git` 이 `gitdir:` 파일)와 **repo 하위 디렉토리**에서 부트스트랩이 거부되거나 오도됐다. `#258` CHANGELOG 가 "형제 결함 별건 이관"으로만 남기고 받는 곳이 없던 항목.
  - **`_cd_repo_root()` 신설** — `phase_1_precheck` 앞에서 subdir → `show-toplevel` 로 이동 + stderr 2줄 고지. 비-git·이미 루트는 무음. `source` 경로에서는 `main()` 밖이라 호출자 cwd 불변.
  - **`_check_git` 판정식** — `--is-inside-work-tree` **출력** 비교(`!= true`). 초안 `--git-dir` 는 `.git` 내부·bare 에서도 rc=0 이라 구 `[ -d .git ]` 가 막던 위치를 통과시키는 **회귀**가 됐다(Phase C 실측 → 본 FID 에서 수정).
  - 테스트 T28.a~i **9건** · `test-init-project` 38→**47** · 변이 M1·M2·M3·M-h·M-i·M-mask 격추. Linux·git 2.5 미만 worktree SKIP 은 NFR 한계.

### Changed
- **`.specops/` 전량 로컬 전용 (20260811)** — `learnings.jsonl` 만 예외로 추적하던 `.gitignore` 규칙을 제거했다. 세션 인사이트에 downstream 프로젝트 문맥이 섞여 배포 저장소에 올리기 부적합하다. `plugin.json` keywords 의 잔존 `downstream-project` 도 함께 제거.

- **단기 로드맵 4건 (20260812)** — (1) `CONTRIBUTING` chain·PASS=26·진입 모드·hooks·llm soft 권고. (2) `skills/engine/*` 유령 경로 → 플랫 `skills/<name>/SKILL.md`(또는 미존재 줄 삭제) + T11 rg=0 락. (3) soft-warn stale `specops_version`/footer 10건 → **1.72.0**. (4) `gbrain-friction` **BYPASS vs receipt** 기본 출력·JSON + T22/T23 · `/gbrain`·gbrain-ko 문서.
- **즉시 로드맵 5건 (20260812)** — (1) `_verify_exec_evidence`/`_bg_pending_path` `$lastedit`에 **MultiEdit** 편입(VERIFY 후 MultiEdit→commit FN 폐쇄) + T-fresh.e·T24c. (2) `agent_tools`가 `-w Edit`만으로 MultiEdit/NotebookEdit를 놓치던 구멍 → 명시 박탈 + T15.e/f. (3) `scripts/README` 헤더 v1.21.2·68 suites·구 baseline → **v1.72.0·142 suites·24/30/33/8**. (4) `specifying-ko used_by`에 `/maintain`·`/promote`. (5) `test-readme-entry-tree` 7→**10종** + 1.72 README foundation/batch 앵커 AC-6.

## [1.72.0] — 2026-08-12

### Fixed
- **문서·일관성 P0 — agents/foundation/entry 드리프트 (20260812)** — `generator-evaluator-ko`가 agents **7종**·`design-reviewer-ko` 부재로 단정해 Phase 2.5-D 필수 dispatch를 거부할 수 있던 구멍 → **8종**+매트릭스 행·`used_by`에 `/start-all`·`planning-ko`. `CLAUDE.md` foundation Step 5.5 **skip** 서술을 specifying SoT(**셸 allowlist**)로 정정 + entry `auto`/`batch`·매칭 순서. `brainstorming-ko`의 `specops-ko:init-project` Skill 오표기 → `/init-project`. 메타/`start.md` PoC v0.0 잔존 문구 정리. `test-design-reviewer-doc.sh` T8–T11·변이로 재발 락.
- **queue.md Phase 0 기계 초기화 (20260812)** — `--classify` 는 있는데 표 쓰기는 산문이라 시드·공통이 PENDING 에 들어가거나 헤더가 빠질 수 있었다. 신규 `init-batch-queue.sh` 가 ELIGIBLE→PENDING · seed/foundation→SKIP · placeholder 생략 · 기존 queue는 REUSE(불변). start-all Phase 0 step 5 배선 · `test-init-batch-queue.sh` · propagation `batch-queue-init`.
- **UI 공통 vs 화면 순서 — foundation Step 5.5 셸 전용 (20260812)** — foundation 이 화면을 전면 SKIP 해 AppShell·토큰이 추측 구현되던 구멍(P0-4). allowlist(`app-shell`·`layout`·`login`) + `<!-- foundation-shell -->` 만 foundation 5.5 허용 · Phase 2.5-A `check-foundation-shell-baseline.sh` snapshot→verify · design-reviewer Critical · `test-foundation-shell-baseline.sh` · propagation `foundation-shell-baseline`.
- **IF 이중 소유 — foundation-baseline 마커 불변 (20260812)** — foundation Step 5.6 이 채운 공통 api-spec/data-model 을 Phase 2.5-B 가 “행 갱신”으로 재작성하던 구멍. `<!-- foundation-baseline -->` 마커 + `check-foundation-if-baseline.sh` snapshot→verify · start-all 2.5-B 배선 · specifying-ko 생산 의무 · design-reviewer Critical · `test-foundation-if-baseline.sh` · propagation `foundation-if-baseline`.
- **`/start-all` Phase 0 foundation 브랜치 머지 게이트 (20260812)** — present 는 manifest 문서만 본다. `§유형=foundation` FID 의 `feat/<FID>` 가 main 미머지(조상 아님 ∧ gh MERGED 아님)여도 batch 가 들어가면 공통 코드가 base 에 없다. 신규 `check-foundation-merged.sh`(KIND는 `foundation-kind.sh` 공유) · present 직후 배선 · `test-foundation-merged.sh` · propagation `foundation-merged-before-batch`.
- **공통부 vs 기능 FR 경계 / hybrid 금지 (20260812)** — `[공통]` 또는 `<!-- foundation-fr: … -->` FR 은 `check-fr-table --classify` 가 `SKIP|…|foundation-scope` 로 내고 `/start-all` queue 에서 **항상 SKIP**(선택 A). `§유형=foundation`∧`§batch` hybrid 는 `check-spec-label-compat.sh` 가 emit-context·verify 에서 HARD FAIL(Argus FR-28 실측). init Phase 11·requirements 템플릿에 표기 규약 · `test-fr-foundation-scope.sh` · propagation `foundation-fr-boundary`.
- **`/start-all` Phase 0 foundation-manifest 선행 게이트 — 없으면 재사용 SKIP 침묵 통과 (20260812)** — `check-foundation-reuse` 는 manifest 부재 시 SKIP 한다. Phase 0 이 requirements만 보면 init 직후 batch 가 공통 재구현을 허용한다(attendance 직전). 신규 `check-foundation-present.sh`: UI/BE/풀스택/모바일 신호(FE·BE arch · decisions · project-context)면 HARD FAIL, CLI 등 비필수는 WARN+rc=0, 파일이 있으면 채움 필수(raw 템플릿 FAIL). `start-all`/`start-all-auto` 배선 · propagation `foundation-before-batch` · `test-foundation-present.sh`.
- **`/start-all` 시드 FR 이중 구현 — 마일스톤 시드(FR-1~3)가 세부 FR 분해 후에도 batch PENDING 에 남던 문제 (20260812)** — init 가 PRD M1~M3 를 FR-1~3 시드로 넣고 Phase 11 이 FR-4+ 를 붙이면, `check-fr-table` 은 시드도 “실 FR”로 세어 queue 에 넣었다(attendance: FR-1+FR-4~9 / Argus 는 수동 `FR-1·2·3 = SKIP`). `check-fr-table.sh --classify` 가 시드 마커(`<!-- seed-fr: FR-1,FR-2,FR-3 -->` 또는 `마일스톤 시드` 문구) ∧ 같은 마일스톤 비시드 실 FR(≥FR-4) 조건으로 `SKIP|…|seed-decomposed` 를 내고, `start-all` Phase 0 이 ELIGIBLE→PENDING · seed-decomposed→SKIP 으로 배선한다. 미분해 시드·마커 없는 구 프로젝트는 SKIP 0(오탐 방지). 테스트 `test-fr-seed-skip.sh` + mutation.
- **CI `test-uiux-assets` U20b 가 Actions 에서만 FAIL 하던 문제** — 검사가 gitignore 된 `.specops/<FID>/acceptance-criteria.md` 를 읽어 로컬(파일 있음)은 PASS·CI clone 은 FAIL 이었다. SoT 를 tracked `CHANGELOG.md` 의 `AC-9 범위 부기` 문구로 옮김.

## [1.71.0] — 2026-08-11

### Changed
- **marketplace 식별자 `specops-ko-local` → `specops-ko`** — GitHub(`andyko18/specops-ko`) 배포에 맞춰 로컬 접미사 제거. 설치 키는 `specops-ko@specops-ko`. 기존 `specops-ko@specops-ko-local` 사용자는 marketplace 재등록 + Claude Code 재시작 필요.

## [1.70.0] — 2026-08-11

### Fixed
- **`/init-project` 종결 커밋이 실행되지 않던 문제 — 목록 소유권을 bash 로 (FID 20260810-init-commit-teeth, #258)** — 부트스트랩이 산출물 18개를 staged 로 남기고 **커밋 없이 끝났다**. 실사용 실측(attendance): `git log` = `does not have any commits yet` · reflog 0 · `.git/COMMIT_EDITMSG` 부재 · friction-log 부재 → **커밋 시도조차 없었다**(거버넌스 차단이 아니다).
  - **근원은 플레이스홀더였다** — `commands/init-project.md:109` 산문이 add 대상을 꺾쇠 플레이스홀더로 두어 **모델에게 목록 재구성을 시켰다**. 그런데 bash 는 `ARTIFACTS_ROOT[@]`·`ARTIFACTS_MEMORY[@]` 로 **정본 목록을 이미 소유**한다(`phases-artifacts.sh:216`). 신규 `scripts/_internal/init-finalize.sh` 가 그 소유권을 되찾는다 — 정본 배열 재-add → 진행기록 append → **단일 커밋** → SHA·파일수 출력. 산문은 **호출 1줄**로 축약됐다(`git add`·`git commit` 리터럴 0건).
  - **`/doctor` 5번째 항목 `bootstrap` 신설**(4→5) — `chore(init):` 커밋 부재로 미종결을 사후 검출한다. `exit 0`·read-only·`--json` 행수 계약 불변. **판정식은 subject 한정**(`--format=%s | grep -c '^chore(init): '`)이다 — `git log --grep` 은 커밋 메시지를 **행 단위**로 매칭해 `^` 앵커가 **본문 줄머리**를 잡는다(실측: 실 repo 3건 매치가 **전부 오탐**, subject 한정 후 0건).
  - **`hooks/hooks.json:45` 하드코딩 인자 제거** — 리터럴 `specops-ko` 를 `ensure-session-progress.sh` 에 넘겨 **downstream 5/5 프로젝트**의 `session-progress.md` 제목이 전부 오염돼 있었다(downstream-dogfood·downstream-company=`specops-ko` · downstream-project·downstream-portal·specops-test2=`specops-auto-ko`). 스크립트 기본값 `basename $(pwd)` 는 원래 정상이었다. 기존 오염분은 **소급 정정하지 않는다**(사용자 repo 파일 — 5원칙 4).
  - **리뷰가 잡은 것** — Phase B: `.bak` 잔존으로 spec §3 "git status clean" 부분 미충족(→ 성공 경로 회수). Phase C **Critical**: repo **하위 디렉토리 실행 시** 상대경로 재-add 가 전부 no-op → `rc=0 "커밋 완료"` **거짓 성공**(AC-2 무력화) — *조용한 실패를 없애려던 스크립트가 같은 클래스를 새로 만들고 있었다*. `cd "$(git rev-parse --show-toplevel)"` 를 **append 호출보다 앞**에 둬 `sub/.specops` 신규 생성까지 함께 차단.
  - **실패 경로 정직성** — 커밋 실패 시 `rc=1` + 사유 원문 + staged 보존 + 재시도 안내. append 를 커밋 앞으로 옮기자 **거짓 "완료" 기록**이 남는 문제가 생겨, `.bak` 복원 + 재-add 로 롤백한다. stale `.bak` 복원은 **pre-rm(출처 증명) + 기록 실재 grep 2중 가드** 뒤에만 — 각 가드 단독으로는 못 막는 구멍(백업 `cp` 만 실패 / append 총체 실패인데 `rc=0`)이 실측으로 확인됐다.
  - 테스트 `test-init-finalize.sh` **14건 신설** · `test-doctor.sh` 29→**31** · 전체 스위트 134→**135** · 변이 M1(재-add 제거) **격추 확인** · R-1 거버넌스 실발화 검증(13종 `.md` staged → allow / `+app.ts` 대조군 → deny).
  - **한계**: 효과(커밋 누락 재발 0)는 **다음 신규 프로젝트 부트스트랩에서만** 확인된다. `semgrep`·`gitleaks` 미설치라 보안은 self-check 만. Linux 미검증. F12/F13 픽스처는 root CI 에서 무력화 가능. **형제 결함 별건 이관** — `phases-artifacts.sh` 도 같은 상대경로 add 이고 `init-project.sh` 전체가 상대경로라 국소 수습은 반쪽이다.

## [1.69.0] — 2026-08-10

### Added
- **ui-ux-pro-max 자산 기반 디자인 시스템 확정 (FID 20260810-uiux-asset-driven-design, #257)** — specops-ko 는 `ui-ux-pro-max`(MIT)를 **cross-marketplace hard dependency 로 설치해 놓고 CSV 자산 참조가 0건**이었다. 유일한 연결이 `specifying-ko:166` 의 Skill 1회 호출(블랙박스)이었고, `/init-project` **Phase 6 은 하드코딩 5택으로 Primary 색 1개만** 채웠다. 자산에는 `colors`(**192유형 × 16토큰**, shadcn 규약)·`ui-reasoning`(**161 컨셉** — 패턴·스타일·핵심효과·안티패턴·`Decision_Rules`)·`styles` 84·`ux-guidelines` 98·`typography` 74·`motion` 16 이 있었다.
  - **실사용 증거**: downstream-dogfood(금융 대시보드)는 `§1.1 금융 도메인 색상`·`§1.4 명암비`·`§5 Motion`·컴포넌트 4종(Metric/Gauge/Chip/Tab)을 **손으로 만들었다**. `Financial Dashboard` 팔레트와 `Data-Dense Dashboard` 패턴·`must_have: high-contrast` 가 **이미 있었는데** 쓰이지 않았다. 이제 제품 유형 하나로 **§1 미채움 0 · hex 16행 · 컨셉 4축**이 들어간다.
  - **결합을 어댑터 1파일에 가둔다** — 신규 `scripts/_internal/uiux-assets.sh` 가 경로·CSV 스키마·라벨 매핑·라이선스 문구·미제공 사유를 **전부** 소유하고, Phase 6 은 함수만 부른다. 결합이 실재하는 위험이기 때문이다: 캐시에 **2.5.0·2.13.0 이 공존**하고 `data/` 구성이 다르며(2.5.0 엔 `design.csv`), 같은 `colors.csv` 가 `src/`·`cli/assets/` **두 곳에 사본**인데 **md5 가 다르다**. 의존 상한이 `<3.0.0` 이라 **minor 는 자동 신뢰**된다. `U8` 이 격리를 잠근다(구현 파일에서 CSV 파일명 발견 시 FAIL).
  - **A안 라벨 매핑 — 무음 사망 방지.** `_inject_design_palette` 는 DESIGN.md **행 라벨을 grep** 하고 실패 시 `[ -z "$hex" ] && continue` 로 **조용히** 넘어간다. CSV 라벨(`Card`·`Foreground`·`Muted Foreground`·`Destructive`)을 그대로 쓰면 4개가 사라져 `screens/*.html` 색 주입이 무음으로 죽는다 → **DESIGN 라벨로 매핑**해 넣고 기존 9라벨을 보존한다(`U11`·`U16` + 변이 M5).
  - **값을 발명하지 않는다.** `Success` 는 어느 CSV 헤더에도 없다 — `colors.csv` 가 **shadcn/ui 규약**이고 shadcn 엔 success 토큰이 원래 없다(`destructive` 만). 고정 녹색 대신 **사유를 적어 비운다**. `Gradient`(컬럼 없음)·**비hex 값 19건**(`rgba(255,255,255,0.08)` Border 등)도 동일하게 skip + 사유 출력.
  - **fallback 3경로 전부 `rc=0`** — 경로 부재·스키마 불일치·중도 실패에서 완전한 DESIGN.md 를 남기고 `/init-project` 를 계속 진행시킨다(부트스트랩 1회 경로라 중단이 치명적). **사유를 출력**한다 — 조용히 빠지면 사용자가 원인을 모른다.
  - **`Decision_Rules` 에 `json.loads` 금지** — 실 자산 **40%(66/161)가 중복키**라 파싱하면 뒤엣것만 남는다(`Financial Dashboard` 는 `real-time-updates` 소실).
  - **우선순위 역전 정정 3곳** — `ui-ux-pro-max 결과 우선, DESIGN.md 후순위` → **DESIGN.md 우선**. per-FID 생성물이 프로젝트 상수를 이기지 않는다(`specifying-ko`·`design-screen`·`start-all`).
  - **템플릿 확장** — §1 에 8토큰 행 추가(17행 = hex 16 + Success 사유행), **§5 Motion·§6 레이아웃 패턴·§7 상태 표현** 신설. 한국어 입력은 LLM 레이어가 영문 유형으로 번역해 `UIUX_PRODUCT_TYPE` 로 넘긴다(자산 목록이 **전량 영문** — 한글 0건 실측).
  - **리뷰가 잡은 것** — plan-reviewer 2회(Critical 3 → Important 5, 2회차엔 리뷰어가 **plan 코드를 조립해 실행**), Phase C(Important 2, **fixture 밖 프로브 6종** 합성). 전건 직접 재현 후 반영: `grep -c \|\| echo 99` → `0\n99` 정수 비교 폭발 · Gradient 범위 모순 · 하네스 진입점 부재(`phases-design.sh` 는 library-only) · **BSD sed `t;` → `undefined label`** · **U8 이 자기 plan 을 격추**(`_leak=1`) · **변이 M4 무효**(U15b 신설로 해소) · **중도 실패 성공 보고**(16행 미주입인데 `작성 완료`) · **awk `sub()` 의 `&` 확장 오염**(`#AB&C` → `` `#AB`#______`C` ``).
  - 테스트 `test-uiux-assets.sh` **63건**(U0~U23+TB1) · **변이 8종 전부 격추** · propagation 114 → **117 edges** · **실 자산 end-to-end**(DESIGN.md → `_inject_design_palette` → CSS 변수 `--color-surface: #0E1223` 등) · 성능 자산경로 204ms vs 5택 28ms(부트스트랩 1회라 무영향).
  - **한계**: **효과 미측정** — 새 프로젝트 부트스트랩에서만 확인된다. **Motion·상태 표현·Typography 값 채움은 후속 FID 이관**(AC-9 범위 부기) — 생성되지 않으면 spec 시나리오가 영구 미충족으로 남는다. LLM 한국어 번역 자동 검증 불가 · 정본 사본 미확증 · `ui-reasoning` 없는 31유형은 색상만 · 실 자산 192행 전수 미검증(픽스처 2행 + 리뷰어 스캔 보완) · Linux 미검증.

### Fixed
- **시한폭탄 테스트 2건 (같은 FID 에서 수습)** — `test-verification-state.sh`·`test-verdict-board.sh` 가 waiver 만료일을 **`2026-08-10T00:00:00Z` 로 하드코딩**해, 그 시각이 지나자 `WAIVED` 가 `NOT_RUN` 으로 계산돼 **두 스위트가 동시에 FAIL** 했다(자정 실발화, `main` 에서도 재현). **프로덕션은 정상이다** — `verification-state.sh` 가 조회 시점에 만료를 계산하는 게 설계이고, 테스트가 "미래" 라고 가정한 값이 과거가 된 것뿐이다. 상대 날짜(`date -u -v+1d` / GNU 폴백)로 바꾸고 **`TB1`** 이 미래 날짜 하드코딩을 잠근다. 과거 날짜(`2020-01-01`)는 만료 거부를 증명하는 의도적 고정값이라 대상이 아니다.
  - 이 수습 없이는 **AC-R-2(run-all 전건 PASS)를 충족할 수 없어** 본 FID 가 자기 AC 를 FAIL 로 두는 모순이 생긴다(Phase B 리뷰어 판정). 사용자 승인 후 포함.


## [1.68.0] — 2026-08-10

### Fixed
- **실행-근거 앵커가 downstream 선언 `test_command` 를 인식 (FID 20260809-runner-anchor-downstream, #255)** — R-1/R-2 커밋 게이트의 러너 앵커가 **specops 자신의 러너 5종만** 인정해, downstream 프로젝트가 테스트를 **실제로 돌려도 커밋이 막혔다**. 외부 4개 프로젝트 실측 **BYPASS 77건**, 실사용 러너 4종(`bash scripts/tests/frontend.sh`·`npx vitest run`·`pnpm --filter … test`·`turbo run test`) **0/4 인정**. BYPASS 사유의 지배적 패턴이 *"테스트를 실제로 돌렸는데 게이트가 안 열림"* 이었다. post-verify 창에서 그 FID `tasks.md` 가 **선언한 `test_command`** 를 앵커로 인정한다 — 러너 **이름을 나열하지 않으므로** 생태계 무관하다(이름 나열은 20260716·Wave A·본 FID 로 이미 **세 번 반복된** 실패 패턴).
  - **기존 앵커 리터럴 3곳은 무수정.** T25 가 그 동일성을 잠그므로(`$lasthit`·`$bghit`·`_bg_pending_path`), OR 확장 대신 **별도 `$declhit` 스캔 블록**을 추가해 `[$lasthit,$bghit,$declhit]|max` 로 합류한다. spec 초안의 *"`$bghit` 는 같은 앵커를 공유한다"* 는 **실측상 거짓**이었고(3중 텍스트 복제) FR-7 을 철회했다.
  - **결과 술어는 2층** — ① `is_error == false`(주, 종료코드 0) ② **꼬리 3줄** 실패 토큰 부재(보조). `VERIFY: PASS` 요구는 **철회**했다(downstream 러너가 그 토큰을 안 찍어 이 경로가 영영 안 열린다). **전체 출력 스캔은 성립하지 않는다** — 규약 성공요약 `PASS=N FAIL=0`(`templates/dispatch-context.md` 가 규정)과 **테스트 설명 줄**(`PASS T16 run-all 실패(FAIL 토큰)`)이 걸려 정직한 성공이 막힌다. 한국어 0-카운트(`실패: 0`·`오류 0건`)도 중화한다 — 한국어 플러그인이 한국어 러너를 막는 건 대상 집단 직격이다.
  - **멀티라인 판정은 안전 접두 화이트리스트.** 인용 문법을 흉내내는 시도가 **두 번 다 뚫렸다** — 따옴표 패리티는 `\"` 이스케이프에, 인용 상태기계는 ANSI-C·`$()` 중첩·백틱에 각각 **false-open** 했다. 셸 인용은 정규 파싱이 불가하므로 방향을 뒤집어, 앞 줄이 전부 `빈 줄`·`cd <경로>`·`set -<flags>`·`export X=Y` 일 때만 명령 시작으로 인정한다. 허용 문자셋에 `"` `'` `` ` `` `$` `\` 가 없어 **폐쇄가 코드 정독으로 확인된다**. 부수로 병리형 지연 1115ms → 22ms.
  - **3중 가드** — heredoc(`<<`) skip · **bg 스텁 차단**(러너를 백그라운드로 띄우고 결과를 보지도 않은 채 커밋이 열렸다) · 결과 존재 확인(`is_error:true` 가 빈 문자열로 조인돼 성공 오판). whitelist 는 `record-task-receipt.sh` 재사용이며 **byte-identity 를 T49 로 잠근다**.
  - **Phase C 리뷰어가 3연속 Critical 을 적중**시켰고 셋 다 사실이었다(전부 false-open). 원인은 매번 **주석에 검증 없이 쓴 "미탐 방향이라 안전"** 주장이었다. plan-reviewer 도 2회 FAIL 했고 그중 하나가 **spec 성공지표의 자기모순**을 잡았다 — "4/4 인식" 목표가 재사용하기로 한 whitelist 때문에 구조적으로 **2/4** 였다(실측 후 spec 정정).
  - 테스트 **T26~T58 신규 33건**(전체 63/63) · **변이 13종** 전부 격추 · **end-to-end 실발화 6/6**(`pretool-governance.sh` 에 `PreToolUse` JSON 직접 투입) · propagation 111 → **114 edges** · 훅 median 125ms 불변, 선언 경로 순증분 +14ms.
  - **한계**: 효과(BYPASS 감소)는 **외부 프로젝트의 다음 커밋에서만** 확인된다. 성공지표 **2/4** — `pnpm --filter <scope> test`·`turbo run test` 는 whitelist 밖(우회 표기 `npx turbo run test`·`pnpm test` 는 통과). 앞줄이 화이트리스트 밖인 정직 실행·`bash -c` 래핑·env 접두·CRLF `tasks.md` 는 미탐. **F-3 의도 위조 미방어** — `export PATH=/tmp/evil`·`cd /가짜repo` 로 가짜 러너를 심는 건 통과한다(설계상 수용). Linux 미검증.

- **변이 테스트 중단 시 실 파일 손상 방지 (FID 20260809-mutation-test-trap, #256)** — `scripts/tests/test-validate-structure.sh` 의 **T-hg.b** 가 `skills/specifying-ko/SKILL.md` **실 파일**을 변이시킨 뒤 `cp` 로 복원하는데 **`trap` 이 없었다**. 위 #255 를 push 하다 **실제로 물렸다** — 180초 타임아웃이 `pre-push` 훅의 `run-all` 을 변이 창에서 죽였고, 규약 문구가 깨진 채 남아 다음 `run-all` 이 원인 불명의 3 스위트 FAIL 을 냈다. `pre-push` 가 `run-all` 을 돌리므로 **push 타임아웃마다 재현**된다.
  - **`trap … EXIT` 은 단독이어야 한다.** `EXIT INT TERM` 이 더 안전해 보이지만 **반대다** — INT/TERM 을 잡으면 셸 기본 종료가 사라져 핸들러가 포그라운드 명령 종료까지 **지연**되고, 뒤따르는 SIGKILL(타임아웃 구현의 전형)을 맞으면 복원이 영영 실행되지 않는다. SIGTERM 만 보내고 `wait` 하면 두 패턴이 **구별되지 않으므로**, 잠금은 `TERM → 유예 → KILL` 로 재현한다.
  - **잠금이 두 번 공허했다.** ① 어미 검사 `^ *trap .+ EXIT *$` 가 **해제 줄**(`trap - EXIT`)에 매치돼 설치 trap 삭제도 통과 ② ` EXIT *$` 가 **`trap "…" INT TERM EXIT`**(다중 시그널의 관용 표기)를 통과. 둘 다 **변이가 격추에 실패한 것**이 신호였다 — 시그널 목록을 **등식**(`= EXIT`)으로 판정하도록 교체했다.
  - **부수 개선** — 프로브가 25.06s 였고 그중 **19s 가 dead wait** 였다(TERM 이 bash 만 죽이고 고아 `sleep` 이 명령 치환의 파이프를 붙든 채 EOF 를 기다림) → **6.08s**. 픽스처 `mktemp` 백업이 매회 시스템 temp 에 **영구 잔존**하던 것도 제거(검증 중 35개 누적) → 0.
  - **계측 재현이 핵심 증거다.** 스위트가 72초라 단순 SIGTERM 은 변이 창을 못 잡는다(첫 시도가 `창포착=0` 으로 **공허**했다). 사본에 `sleep 12` 를 삽입해 창을 벌리고 포착 확인 후 SIGTERM → 현행 **RESTORED** / 무trap 대조 **CORRUPTED**.
  - `test-git-hooks.sh` GH-8 은 **이미 `trap … EXIT`** 이라 무수정. 변이 **6종** 전부 격추(리뷰어가 격리 사본에서 trap 표기 10종까지 전수 실행).
  - **한계**: **SIGKILL 은 트랩 불가**(복구는 `git checkout skills/specifying-ko/SKILL.md` — 주석 명시). trap 줄 끝 주석을 적대적으로 조작하면 통과하는 **false-pass 1형태**. macOS bash 3.2 만 실측.

### Changed
- **선행 기록 정정** — `20260809-runner-anchor-downstream` 의 evidence·gbrain 에 *"변이 전 `trap … EXIT INT TERM` 이 필수"* 라고 **검증 없이** 기록했다. 실측으로 반증됐고 #256 의 인사이트가 정정본이다.


## [1.67.0] — 2026-08-09

### Added
- **plan-reviewer 1회차 FAIL 예방 사전검사 (FID 20260809-predispatch-fail-check)** — 리뷰 비용 구조를 재보니 **초과 첨부보다 재dispatch 가 훨씬 크다**: 계약 밖 아티팩트 첨부는 dispatch 당 **5~11k(8~14%)** 인데 **1회차 FAIL 로 인한 재dispatch 는 +62~91k** 다(실측). 그리고 plan-reviewer **1회차 FAIL 이 5/5**. 신규 `scripts/_internal/check-plan-predispatch.sh` 가 그 FAIL 을 만든 결함 중 **기계 판별 가능한 3클래스**를 dispatch **직전**에 잡는다 — ① **dangling-lock**(잠글 문자열이 repo 에도 plan 구현부에도 없어 어서션이 영구 FAIL) ② **propagation-schema**(파서가 소비하는 `.edges[].path` 부재로 잠금이 무음 사망) ③ **red-evidence**(선-green 단정에 실측 근거 부재). `planning-ko` 가 dispatch 직전 호출하고 rc=1 이면 수정 후 재실행한다.
  - **리뷰어를 대체하지 않고 왕복만 줄인다.** 판별이 애매하면 **통과**시킨다(미탐 선택) — 오탐은 정상 plan 을 막아 게이트 신뢰를 깎는다. 실 코퍼스 **28건 오탐 0**.
  - **구현 중 실측이 규칙 2개를 좁혔다.** red-evidence 초안은 **21/28 오탐** — 원인이 `planning-ko` **자신의 정본 템플릿**(`실행:` + `예상: FAIL` 산문)이었다. 정본 형식을 결함으로 보는 규칙은 오탐 생성기다 → "**이미 통과한다**"는 선-green 단정 한정으로 축소(0/28). propagation-schema 는 `"id"` 만으로 골라 무관 JSON 2건을 잡았다 → propagation 어휘 동반 요구.
  - **4번째 후보(AC 검증방법 ↔ 테스트 대조)는 반증 실측으로 기각했다** — 실제 Phase B FAIL 시점의 테스트 파일에 AC 가 지목한 토큰이 **이미 6회** 있었다. 토큰 검사는 통과시킨다(미탐). 결함은 "어느 픽스처에 대조가 없다"는 **의미론**이라 토큰 수준에서 판별되지 않는다. 부수 실측: 전 FID `**검증 방법**` 196건 중 **35건(18%)이 산문만**.
  - **리뷰어 dispatch 입력 계약**도 명시 — `agents/*-reviewer-ko.md` 의 "받는 컨텍스트" 는 **이미 최소**인데(`tasks.md`·`plan.md`·`clarifications.md` 는 거기 없다) 부모가 임의로 얹고 있었다. 계약 밖 경로를 첨부하지 않고 리뷰어가 `NEEDS_CONTEXT` 로 당겨간다(push → pull).
  - **리뷰가 결함 5건을 잡았다.** Phase B: AC-5 가 **계약 drift** — 실측이 규칙을 좁혔는데 AC 본문이 초안 트리거 그대로였다. 리뷰어 판정 *"NFR-3(오탐 0 · must)이 이긴 것이 옳고 **코드 되돌리기는 오히려 NFR-3 위반**"* → `/clarify` append(AC-8·AC-9), 코드 무변경. Phase C: ① 인용 줄 **통삭제**가 `echo 'X' >> f && grep -q 'X' f` 처럼 한 줄이면 구현 증거까지 지워 **오탐** ② `Step` 헤더에 숫자 경계가 없어 `Step 25` 오매치 ③ 음성 어서션 4건이 `rc=0` 만 봐서 픽스처 소실 시 `SKIP`(rc=0)을 PASS 로 읽는 **공허** ④ **jq 부재 시 규칙 2 가 무음 사망** — "잠금의 무음 사망"을 잡는 규칙이 스스로 같은 모드로 죽는다.
  - 어서션 **P0~P14 15건**, **변이 7종** 전부 격추. 그중 하나는 **부모 자체 변이가 P14 의 공허를 발견**한 것이다 — 픽스처를 `Step 25 → 26` 으로 썼더니 버그판이 미탐 경로로 빠져 격추되지 않아, 뒤에 비-2X 스텝을 두어 오탐을 내도록 바꿨다. propagation 109 → **111 edges**.
  - **한계**: 표본은 plan-reviewer FAIL **5건**이고 3클래스가 덮는 것은 **4건**이다. **가장 비쌌던 68k 건(클래스 ④)은 못 막는다.** red-evidence 는 실 코퍼스 발화 0 — 오탐 0 의 증거지만 검출 실적도 0이다(다만 코퍼스는 이미 리뷰를 통과한 **생존자 표본**이라 검출력 0 의 증거는 아니다). 효과(1차 통과율)는 본 FID 에서 측정 불가 — 후속 관측 대상. 의도된 미탐 4종(메타문자·4자 미만·jq 파싱 실패·어휘 부재). Linux 미검증.

## [1.66.0] — 2026-08-09

### Fixed
- **`active-fid` 마커 생산자 신설 (FID 20260809-active-fid-marker-producer)** — `hooks/governance-lib.sh` 의 `detect_fid()` 는 `.specops/session-progress.md` 의 `<!-- active-fid: <FID> -->` 를 **1순위**로 읽는데(주석의 U8 — 다중 FID 환경 first-only 회피), 그 마커를 갱신하는 층이 **0곳**이었다(`session-progress-append.sh` 의 `active-fid` 참조 0건 실측). **소비자만 있고 생산자가 없어** 한 번 기록된 값이 영원히 고착됐다. 실사용 관측: R-1 게이트가 현재 FID 가 아니라 **직전 FID** 의 verify 증거를 요구해 `git commit` 이 **2회 차단**됐고 사람이 수동 `sed` 로 풀었다.
  - **2순위 fallback 이 대신 맞아주지 않는다** — 섹션은 **prepend** 되므로 첫 h2 헤더는 "가장 최근 **생성**된 FID" 이지 활성 FID 가 아니고, **재개 시 둘이 갈린다**. 마커가 도입된 이유가 정확히 그것이라, 마커 폐지는 U8 버그 복원이다. `detect_fid()` 는 **무수정**(2순위는 마커 이전 파일용으로 보존 — AC-R-1).
  - **치환·삽입 양방향** — 마커가 **없는** 파일(신규 프로젝트·구 파일)에서 치환 단독은 조용한 no-op 이라 그 파일이 영원히 2순위에 머문다. GNU/BSD `sed -i` 인자 분기를 피해 awk + `mv` 원자 교체.
  - **리뷰가 결함 6건을 잡았다.** Phase B: ① AC-2 TEST_GAP(삽입 픽스처에 `detect_fid` 대조 부재 — 삽입·치환은 별개 printf 라 한쪽만 깨지면 1순위가 조용히 무력화된다) ② 수습 중 발견 — 픽스처가 섹션 1개라 새 FID append 시 **새 섹션이 맨 위에 prepend** 되어 **2순위도 같은 답**을 냈다. 두 경로가 일치해 어서션이 **구조적으로 공허**했고 `-->` 제거 변이가 25/0 통과했다 → 섹션 2개·대상이 두 번째인 판별 픽스처로 교체. Phase C: ③ **생산자 `^<!--` 앵커 ↔ 소비자 무앵커 grep 비대칭** — 선행 공백이 붙은 마커(수동 편집 흔적, **이 결함의 기원이 바로 수동 sed**)를 생산자가 못 보고 아래에 새로 추가하면 소비자 `grep -m1` 이 위쪽 stale 을 먼저 집는다. **재실행해도 자기치유되지 않는다**(프로브 실증: 두 번 돌려도 `detect_fid=20260101-stale`) — **이 FID 가 고치려는 결함이 입력 1클래스에 그대로 잔존**했다 ④ 무음 실패 ⑤ END fallback 미검증 ⑥ 다중 마커 잔존.
  - 어서션 **M1~M10 + M2b** 신설, **변이 6종** 전부 격추 — upsert 호출 제거 `FAIL M1·M2·M3·M4` · 삽입 분기 제거 `FAIL M2` · 삽입/치환 printf `-->` 제거 각각 `FAIL M2b`/`FAIL M4 (detect_fid='20260505-decoy')` · 앵커 원복 `FAIL M9 (마커수=2, stale 고착)` · END fallback 제거 `FAIL M10`. propagation 106 → **109 edges**(producer↔consumer 3-edge 잠금).
  - **실사용 자가검증**: 구현 직후 이 FID 로 append 하자 마커가 즉시 따라왔고, 이어진 `git commit` 에서 R-1 게이트가 **올바른 FID** 를 요구했다.
  - **한계**: "가장 최근 append = 활성 FID"는 **휴리스틱**이다(두 FID 번갈아 진행 시 마지막에 손댄 쪽). 현행(영원히 고착)보다 엄격히 낫다. Linux 미검증 · override 사유 문자열은 `risk-profile.sh` 가 영속하지 않음(기존 동작).

### Added
- **`plan.md` → `tasks.md` 골격 기계 생성기 (FID 20260809-plan-to-tasks-generator)** — `decomposing-ko` 가 `tasks.md` 를 쓸 때 `plan.md` 내용을 상당 부분 **재타이핑**한다. 실측: tasks.md 의 substantive 줄 중 plan.md 와 **완전 동일한 줄**이 3 FID 에서 **44%·55%·63%**. 신규 `scripts/dag/plan-to-tasks.sh` 가 단일 awk 패스로 Task 블록(`**파일**` 블록·Step 본문·코드펜스)을 추출해 **stdout 으로만** 낸다 — 실측 결과 골격이 기존 tasks.md 의 **80~86%** 를 커버한다(504/604 · 311/359 · 291/361). `decomposing-ko` 는 그 위에 생성기가 만들지 않는 4섹션만 쓴다.
  - **`## 의존 그래프` YAML 을 의도적으로 만들지 않는다** — 이것이 설계의 핵심이다. `depends_on` 은 plan.md 에서 도출 불가한데, `[]` 로 채우면 `dag::find_independent_batch` 가 전 태스크를 절대 leaf 로 보아 **거짓 병렬**이 열린다(실측: 3-task all-leaf → `T1 T2 T3` **무경고** 반환). 반대로 per-task `ac` 는 비워도 `emit-context.sh` 가 `must AC 미커버` 로 dispatch 를 차단하므로 **관문이 강제**한다 — 두 필드의 처리가 다른 이유가 이 **게이트 비대칭**이다. 센티널 주입도 기각(리스트 아닌 값이 파서에 들어가는 위험). 포기하는 절감은 YAML 약 30줄뿐이다.
  - **파싱 실패 = 전면 거부**(rc=1 + stdout 빈손). Task 헤더 0건·Step 0개 Task·plan 부재 3경로, 사유는 stderr 로 구별. 부분 골격을 내면 "완성처럼 보이는 반쪽 산출물"을 **스크립트가 양산**하게 된다. 실측 파싱 성공 **22/28** — 실패 6건은 Task 블록이 없는 산문형 plan(5건)과 Step 0개 Task 를 가진 plan(1건, `20260711-g0-batch-e2e`)이다. 정규식만 보던 사전 기준선(22/27)과의 차이는 후자가 **설계대로 거부**된 것이다.
  - **읽기 전용**(워킹트리 델타 0 검증) · Step 개수를 **세지 않는다**(실측: Task 78건 중 5-Step 은 **49%뿐** — 2개 11건·6개 8건·7~9개 6건) · 파일 라벨 6종 원문 보존(수정 52·테스트 25·생성 15·Modify 9·삭제 3·Create 3) · **코드펜스 길이 추적**(4-backtick 안의 3-backtick 을 종료로 오인하지 않음 — 실측 1건 실재).
  - **성공지표에서 "plan-reviewer 토큰 52%(525k) 절감"을 명시 제외했다** — 이 생성기는 `plan.md` 를 건드리지 않으므로 plan-reviewer 입력이 1토큰도 줄지 않는다. 제안 시점에 그 근거를 썼다가 실측으로 정정했고, 그 정정 이유를 spec §1 에 남겼다(직전 FID 의 충족 불가 AC 리터럴과 같은 클래스를 피함).
  - **plan-reviewer 가 2라운드 연속 실결함을 잡았다** — 1회차 Critical 2: ① T15 가 잠그려던 `BATCH-PHASE1-DONE:decomposing-ko` 가 **repo 전체 0건**이라 영구 FAIL(실물은 `BATCH-PHASE1-DONE: <FID>`) ② propagation edge 를 `{source,contract,consumers}` 로 제안했으나 실물 파서는 `.edges[].path/.must_match` 만 소비 → **무음 no-op**, spec 이 지정한 잠금이 설치 즉시 공허. 2회차 Important 2: ③ 변이 M2("펜스추적 제거 → FAIL 기대")가 **실행하면 diff 0** — fixture 의 내부 3-fence 가 **짝수**라 naive 토글이 우연히 복귀, AC-12 의 "변이 시 FAIL" 이 원리적 불성립이었다(홀수 + `###` 함정 헤더로 재설계) ④ `git ls-files` 는 **untracked 를 세지 않아**(실측 0 vs staged 1) T0 가 즉시 FAIL·finish 해 RED 6건 관측 불가. **네 건 모두 "RED·변이 결과를 실행하지 않고 단정"** 이라는 동일 클래스이며, 이는 **직전 릴리즈(v1.65.0)가 `planning-ko` 자체검토 항목 7 로 신설한 바로 그 검사**다 — 규칙을 만든 다음 FID 에서 저자가 두 라운드 연속 재현했다.
  - 어서션 **20건(T0~T19)**, 변이 4종으로 비-vacuous 확인 — 거부 반전 `FAIL T8` · 펜스추적 제거 `FAIL T7 (^## Task=2)` · Step0 거부 제거 `FAIL T9 stdout=550자` · run-all glob 제거 `FAIL T16`. propagation 101 → **106 edges**.
  - **Phase C 가 프로브로 경계 결함 3건을 격추했다** — ① 닫는 펜스를 `==` 로 판정해 **CommonMark 유효한 3-open/4-close 문서에서 뒤 Task 가 무음 병합**(주석이 CommonMark 를 잘못 인용하고 있었다. 규격은 "닫는 펜스는 여는 펜스 **이상**") ② **Step 카운트에 fence 가드가 없어** 코드펜스 안의 예시 Step 이 실제 스텝으로 계수 → zero-step 거부(AC-2)를 **우회**(이 repo 의 plan.md 자체가 그 입력 클래스다) ③ T12 가 `parse-dag.sh` 부재 시 `_y` 빈손 → `batch=0` 으로 **영구 통과**. 셋 다 수정 + T18·T19 신설 + T12 가드로 잠갔다. ①은 `reconcile-check` 에도 같은 오탐을 심을 뻔했다(동일 커밋에 함께 교정).
  - **한계**: 절감의 **실제 효과**(생성 골격을 모델이 얼마나 안 고치고 쓰는가)는 본 FID 에서 측정 불가하다 — 후속 FID 의 decomposing 출력 관측 대상이다. mawk 의 `{2,3}` interval 지원은 로컬 검증 불가(NFR-1 "Linux 미검증" 명시).

## [1.65.0] — 2026-08-08

### Added
- **`planning-ko` 자체 검토 4항목 + AC 개수 상한 안내 (FID 20260808-plan-selfcheck-ac-cap)** — 이번 세션 실측이 근거다: `plan-reviewer` **1회차 FAIL 3/3(100%)** · plan-reviewer 서브에이전트가 세션 토큰의 **52%(525k)** · 코드 **18줄** 변경에 AC **12건**(plan 558줄·tasks 468줄). 세 FID 의 Critical 이 **같은 클래스**였다 — 기존 테스트가 폐기 대상의 의미를 고정하는데 plan 이 승계를 일부만 특정했다. 자체 검토를 3 → 7항목으로: ④ **기존 테스트 승계 스캔**(판정 의미가 바뀌면 **양성 대조군을 요구하는 어서션이 조용히 깨진다** — 픽스처를 고칠지 단언을 뒤집을지는 **양쪽을 실제로 돌려보고** 정한다) ⑤ **어서션 실행 가능성**(`.gitignore` 경로를 `git diff` 로 검사·미실행 분기의 변이 앵커·`PATH` 통교체로 `bash` 자체 유실 — 전부 실제 발생) ⑥ **복구 절차 안전성**(`git checkout` 이 미커밋 구현 파괴 → `cp` 백업) ⑦ **RED 예상 실측**. 넷 다 **판정 질문**임을 blockquote 로 못박았다 — 답이 길어지면 리뷰 대상이 늘어 역효과다. `specifying-ko` 에는 **AC 개수 상한(should)** 을 넣되 **하드 게이트로 만들지 않았다**: 기계 강제는 must AC 누락을 유발하고, 줄일 것은 AC 개수가 아니라 **설명으로 쓴 AC** 다(반대 방향 경고 병기 — 누락 시 `emit-context` 역방향 커버리지가 막는다). 신규 `test-plan-selfcheck.sh`(T0 가드 + T1~T4)로 산문을 회귀 잠금, run-all **130 → 131**.
  - **이 FID 자체가 신설 규칙의 첫 반례였다 — 재귀 2회.** Phase B FAIL: `AC-R-1` 리터럴("삭제 줄 0" · "run-all 130/130")이 **원리적으로 충족 불가**였다(`specops_version` 갱신 = numstat 상 1삭제 / 신규 스위트 자동 편입 = 131). 리뷰어 판정 *"재dispatch 대상은 implementer 가 아니라 계약서"* → `/clarify` append 로 `AC-R-1b` 정정, 구현 무변경. 이것이 신설 **항목 7** 이 잡는 클래스다. Phase C Important 2건: T3 의 whole-file grep 이 다른 절의 `상한`·`should` 에 매치해 **should 성격만 지워도 통과**, T4 의 양성 대조군(`check-ac-format.sh`)을 **내가 추가한 201행이 오염**시켜 보존 대상 bullet 을 통삭제해도 통과 — **회귀 잠금이 태어날 때부터 공허**했다. 이것이 신설 **항목 4·5** 가 잡는 클래스다(리뷰어 명명: "두 번째 재귀 사례"). 프로브 P1·P3·P5 로 재현 후 행 스코프·앵커 교체·T0 가드로 수정, 세 프로브 전부 격추 확인.
  - **한계 명시** — 본 변경의 실제 효과(plan-reviewer 1차 통과율 상승)는 **이 FID 에서 측정 불가**하다. 검증한 것은 "지침이 실재하고 회귀로 잠겼다" 까지이며, 효력은 후속 FID 의 dispatch-log 관측으로만 확인된다.

### Fixed
- **마찰 집계 증류 후보를 block 기준으로 — warn 감사기록 오계상 (FID 20260808-friction-candidate-accuracy)** — `gbrain-friction.sh` 의 증류 후보 판정이 **전체 행수**(`$2`)를 임계와 비교했다. 그런데 R-1/R-2 는 **pretool=차단 / posttool=감사**로 역할이 분리돼 있어, 같은 사건 하나가 block 1행 + warn 1행으로 **두 번 적재**된다. 결과적으로 감사 기록이 증류 신호로 오계상돼 후보 순위가 부풀었다(실측 R-1 126행). 판정을 `severity=block` 건수(`$6`)로 옮겨 **실제로 흐름을 막은 횟수**만 후보를 만들도록 했다 — 감사 기록은 여전히 표에 남지만 후보 판정에는 쓰이지 않는다. TSV 6번째 컬럼 신설, 빈 timestamp 로 인한 필드 붕괴도 함께 봉합(`lt = (last[r] == "" ? "?" : last[r])`).
- **`/doctor` progress 판정 — 아카이브 FID 를 영구 경고로 세던 결함 (FID 20260808-doctor-progress-archive)** — `progress` 점검이 `/verify PASS` 기록 대비 `evidence.md` 부재를 불일치로 보는데, **디렉터리째 정리된 과거 FID** 도 그 조건에 걸렸다. 실측: 불일치 **83건 전부가 디렉터리 부재**였고 `evidence.md` 만 없는 경우는 **0건**이었다(누락 `20260426~20260702` · 실재 `20260709~` 로 날짜가 깨끗이 갈린다 — 7월 초 일괄 정리 흔적). `.specops/*` 는 `.gitignore` 대상이라 로컬 전용이고 `session-progress.md` 는 append-only 이므로 **의도된 정리인데 결함으로 읽혔다**. 조치 문구("evidence.md 확인 또는 `/verify` 재실행")도 6주 전 FID 에는 **수행 자체가 불가능**했다. 결과적으로 `/doctor` 는 **끌 수 없는 ⚠️** 를 매번 띄웠고, 항상 켜진 경고는 아무도 읽지 않는다 — **직전 FID(#248, pre-push CI 경고)가 고친 "신호가 없어 안 읽힘"의 정확한 반대편(신호 포화)** 이다. 판정을 3분류(아카이브/불일치/정상)로 바꾸고 아카이브는 `아카이브 N건 제외` 로 **표기**한다(0건이면 미표기 — 잡음 금지). 불일치로 남는 것은 `디렉터리 있음 + evidence.md 없음`, 즉 **검증 주장 후 증거 유실**이라는 진짜 결함뿐이다. `checks` 배열은 4건 불변(`--json` 계약). `arch` 를 기존 `bad` 와 **대칭으로 dedup** 한 것이 핵심 — 이 repo 는 FID 섹션 125건에 디렉터리 32개라 중복 헤더가 개연이고, 비대칭이면 건수가 조용히 부푼다(T26 이 잠금). 성능은 루프에 `[ -d ]` 가 추가되나 bash 내장이라 스폰 0 — 실측 **0.130s → 0.128s**(n=5, 측정 노이즈 수준. NFR-2 예산 2s). 원 FID `20260807-specops-doctor` 의 **must AC-5 를 대체(supersede)** 하며, 종료된 FID 의 계약서는 이력 보존을 위해 수정하지 않고 승계를 본 FID 에 기록했다. 어서션 9건 신설(`T18`~`T26`, 총 28), 변이 3종으로 비-vacuous 확인 — 문구 무조건화 `FAIL T22` · 5번째 `checks` 승격 `FAIL T23 n=5` · dedup 제거 `FAIL T26`.
  - **독립 리뷰가 2라운드에 걸쳐 검증 절차 결함 4건을 잡았다** — 전부 **plan 문서의 어서션이 실제로 판정하지 않는** 계열이다. ① `AC-10` 의 검증 절(`git diff` 에 원 FID 경로 부재)이 **`.gitignore:5` 때문에 구조상 영원히 통과**(vacuous) → 원 계약서에 승계 문구 **부재**를 직접 검사하는 형태로 교체 ② 변이 앵커가 `_add progress ok` 라 warn 경로 픽스처에서 **미발화**해 증명이 성립하지 않음 → `warn` 앵커로 교체 ③ 복구 가드 `git diff --exit-code` 가 커밋 전이라 **복구가 완벽해도 rc=1** ④ 그 교체분 `grep` 이 이 워크스페이스의 zsh 함수 래퍼에서 패턴 중간 raw `$` 를 anchor 해석해 **복구 완료인데 "미복구"** 거짓 출력(래퍼 rc=1 / `/usr/bin/grep` rc=0 / `-F` rc=0) → `grep -F` 강제. ③④ 는 가드가 막으려던 "복구 실패 오인 → 파괴적 복구" 를 **가드 자신이 유발**하는 형태였다.
  - `emit-context` 게이트도 실결함 1건을 잡았다 — `AC-R-1` 을 산문("전 태스크 공통 규칙이 담당")으로만 두고 어느 태스크 `ac` 배열에도 넣지 않아 **must AC 미커버**로 차단됐다. receipt 게이트는 `T26` 이 T1 시점에 green 이 될 수 없는 배치 오류를 잡았다(T2 로 이동). **둘 다 사람이 못 본 것을 기계가 잡은 사례**다.
  - 한계 명시 — "디렉터리 부재 = 무조건 아카이브"라 **실수로 지운 최근 FID 도 조용히 통과**한다(날짜 임계값은 근거 없는 마직수라 기각). 또한 이 변경 후 해당 판정은 이 워크스페이스에서 **영구 ✅** 라 실사용 관측 신호가 0 이 된다 — 동작의 유일한 증거는 픽스처와 변이 테스트뿐이다.

## [1.64.0] — 2026-08-08

### Added
- **pre-push CI 상태 경고 (FID 20260807-doctor-ci-check)** — 2026-08-07 `main` 이 **3커밋 연속 Linux CI red** 였는데 아무도 몰랐다. 원인은 `_parse_numbered` 의 awk 로케일 의존이었고, **로컬 게이트가 전부 macOS**(pre-commit·pre-push) 라 Linux 를 보는 층이 CI 하나뿐이었다. 신호는 GitHub 에 있었으나 **소비 지점이 없었다** — `friction-log` 가 25개 파일에 흩어져 안 읽히던 것과 같은 실패 형태다. `/doctor --ci` 는 기각했다: NFR-2(2초·네트워크 없음)와 정면 충돌하고, **수동이라 3일간 아무도 안 돌린 것이 이번 사고**다. push 는 자동으로 일어난다. 신규 `check-ci-status.sh` 가 판정 SoT 이고 훅은 호출만 한다(FR-8). 면제 4종 **뒤**·`run-all` **앞**이 계약 — 앞이면 비-specops repo 에서 `gh` 를 부르는 월권, 뒤면 195초 늦는다(실측 배선 `면제:29 < ci:34 < run-all:38`). **항상 `exit 0`**(게이트화는 오프라인 개발을 막으므로 범위 밖). 결론 분류는 **allowlist** — `success`·빈 값만 조용하고 나머지는 전부 경고한다. blocklist 로 실패 결론을 열거하면 GitHub 가 문자열을 추가·개명할 때 조용히 green 이 되는데, 그건 워크플로 이름 하드코딩을 clarify Q2 가 기각한 것과 같은 실패 형태다. GNU `timeout` 은 macOS 에 없어 bash 3.2 워치독으로 상한을 걸었고, **`pkill -P` 가 동작 조건**이다 — `kill` 은 래퍼 셸만 죽여 고아 자식이 명령치환 파이프를 물고 놓지 않는다(실측 A/B: 미적용 **30.02s** / 적용 **1.05s**). 왕복 실측 1.01/0.99/1.00s → NFR-2(3초) 충족, 기본 타임아웃 5초는 5배 여유. 어서션 14건(`GH-ci.1`·`.1b`·`.2`·`.3`·`.4`·`.4b`·`.5`·`.5b`·`.6`~`.9`·`.R1`·`.doc`), 변이 **5종**으로 비-vacuous 확인 — 워치독 무력화 `FAIL 소요=30s` · `exit 0`→`7` `rcs=[0 0 0 0 7 0]` · 파일 쓰기 주입 트리 해시 변화 · 그룹 kill→`pkill -P` 복원 `FAIL 소요=31s` · sentinel `"-"`→`""` 복원 `결론: deadbeef00112233`. **독립 리뷰가 3라운드 전부 실결함을 잡았다** — plan-reviewer Critical 2건(테스트의 `PATH` 완전 교체가 `bash` 자체를 못 찾아 rc=127 **영구 FAIL**·GH-ci.6 연쇄 / 변이 실험의 `git checkout` 복구가 **미커밋 구현 파괴**), Phase C Important 2건(아래). 후자 2건은 **부모 자기검증이 전부 놓친 것**이다.
- **CI 경고 스크립트의 프로세스·파싱 결함 2건 (Phase C 적발)** — ① **워치독이 depth-1 한정**이었다. `pkill -P "$pid"` 는 직계 자식만 죽여서 `gh` 가 손자를 띄우면 타임아웃이 **통째로 무력화**된다(프로브 실증: `TIMEOUT=1` 인데 HANG 10s+, 고아 `sleep 30` 잔존). hang 지점이 pre-push 의 "run-all 실행 중" 안내 **앞**이라 push 가 **무출력 동결**된다 — 사용자에겐 도구가 멈춘 것으로 보인다. `set -m` + `kill -TERM -- -$pid`(프로세스 그룹째)로 교체. ② **빈 필드 시프트** — 탭은 bash 의 IFS whitespace 라 **연속 구분자가 collapse** 되는데 jq sentinel 이 `// ""` 였다. `conclusion` 부재 응답에서 SHA 가 결론 칸으로, URL 이 커밋 칸으로 밀려 경고문이 `결론: deadbeef00112233` 로 오염됐다(false-green 은 불가하고 `exit 0` 도 유지돼 AC 계약은 안 깨지나 경고 신뢰성이 죽는다). sentinel `// "-"` + `"-"` 는 파싱 실패로 보고 침묵(spec §7 안전 방향). 두 수정 모두 어서션 신설(`GH-ci.5b`·`GH-ci.1b`) 후 **구 코드 복원 변이로 FAIL 유도 확인**. **`set -m` 은 stderr 계약(AC-2)에 닿는 변경이라 Linux bash 5.2.37 컨테이너에서 별도 실측**했다 — 잡 컨트롤 알림 누출 0, 스위트 25/25 PASS. 이 FID 자체가 "로컬 게이트가 전부 macOS 라 Linux 결함을 놓쳤다"에서 출발했으므로 같은 갭을 반복하지 않았다.
- **재개 시 산출물 완결성 경고 (FID 20260807-reconcile-completeness)** — `reconcile-check.sh` 는 아티팩트의 **파일 존재만** 보고 단계 완료로 계산했다. 토큰 한도(5시간/주간)로 `/plan` 중간에 끊기면 반쪽 `plan.md` 가 남는데, 재개점 계산은 그걸 "plan 완료"로 읽는다 — 실증: `## 1. 가정` 만 있는 **2줄짜리** plan.md 에 `--hook` 이 `재개점: tasks 부터` 를 새 세션에 주입했다. 사용자의 실사용 패턴("한도 풀리면 `진행해` 한 마디로 재개")에서 조용히 틀리는 경로다. 3신호 OR 판정 — `heading-end`(마지막 비어있지 않은 줄이 `#`) · `odd-fence`(``` ``` ``` 시작 줄 홀수) · `table-hdr`(끝 3줄에 표 구분행만). **warn-only** — evidence 사다리와 `evidence > recorded` 비교를 건드리지 않아 frontier 계산은 불변이다(오탐 피해가 경고 1줄로 묶임). 대상은 `plan.md`·`tasks.md` 2종(`evidence.md` 는 R7 구조화 판정이 이미 커버). **배제된 대안 2종은 실측이 죽였다** — 템플릿 필수섹션 매칭은 실 산출물 22건 중 7섹션 전건 충족이 10건뿐(**오탐 55%**, 279줄 완성 plan 이 2/7 매칭 — 헤딩을 번호 없이·다른 번호·자유 제목으로 씀), footer 존재 판정도 plan 15/22·tasks 13/21 로 **오탐 32~38%**(미준수 8건은 전부 정상 완료). 채택안은 실 산출물 45건 순회 **오탐 0**. 신규 판정 원칙이 아니라 기존 R7("파일 존재 ≠ 단계 완료", verify 축)의 plan·tasks 축 확장이다. 한계 명시 — 문장 중간 중단·빈 파일·구분행이 끝 3줄 창 밖으로 밀린 경우는 미탐(spec §7-1, 코드 주석 기재). 테스트 R10~R22 신설(총 22건), differential sentinel 로 판정 반전 시 10건 FAIL 확인.

### Fixed
- **`evidence < recorded` 오표기 — 거짓 안심 제거** — 비교가 `evidence > recorded` **단방향**이라 역방향이 else 로 흡수돼 서로 다른 값을 `=` 로 표기했다(`✅ 정합 — 기록(clarify) = 증거(specify)`). 3갈래로 분리해 `ℹ️ 기록이 증거보다 앞섬 — 기록(X) > 증거(Y)` 로 정정. 정합 문구는 **원문 보존**(`show-fid-status` byte-동일 위임 계약 유지). 커밋 `9202864`(Wave A 거짓 안심 제거 — audit·reconcile·receipt)의 잔여 표면이다.
- **SessionStart notice 거짓 단언 (자기 결함 — 완결성 경고가 유발)** — 종전 `--hook` 계약은 "비어있지 않음 ⇔ DESYNC" 였는데, 완결성 경고를 DESYNC 와 **독립** 방출하게 바꾸면서 `session-start.sh` 의 notice 가 과소보고도 재개점도 미기록 단계도 없는 상태에서 "재개점부터 진행하고 `session-progress-append.sh` 로 보정하라"를 **매 세션 주입**하게 됐다. SessionStart 컨텍스트는 자율 lifecycle 에서 행동을 직접 구동하므로 불필요한 보정 시도를 유발한다. `recon_out` 의 DESYNC 포함 여부로 notice 를 분기(경고-only 는 "휴리스틱이라 오탐 가능, 재개점 자체는 정상")하고 `test-session-start-reconcile.sh` S4 로 고정. **Phase C code-reviewer-ko 가 훅을 직접 실행해 적발**했다 — 부모 자기검증에서는 안 보였다.
- 판정 함수 부수 결함 2건 — 읽기 권한 없는 파일의 `grep`/`tail` stderr 가 `/status` 사용자 출력에 누출(`2>/dev/null` + `fences` 가드, R21) · markdown 합법인 pipeless 표 데이터 행(`a | b`)을 데이터로 안 쳐서 `table-hdr` 오탐(구분행 뒤 **모든** 비어있지 않은 줄을 데이터로 인정 — FR-1 "데이터 행이 뒤따르지 않음"은 파이프 스타일을 한정하지 않는다, R20).
- **백그라운드 검증 러너가 실행 증거로 인정되지 않던 결함 (FID 20260807-bg-verify-evidence)** — R-1/R-2 실행-근거 게이트는 `tool_use`↔`tool_result` 를 id 로 join 해 **그 결과 본문**에서 `VERIFY: PASS` 를 찾는다. 백그라운드 Bash 는 `tool_result` 가 실행 출력이 아니라 스텁("Output is being written to: …")이라 토큰이 없고, 실제 출력은 이후 `Read` 결과에만 있다 — **정직하게 러너를 완주시키고도 증거 0으로 판정돼 커밋이 막혔다**(실측: `run-all` ~195s 재실행 낭비). 오래 걸리는 검증일수록 백그라운드가 자연스러운데 정확히 그 경우에 증거가 무효가 됐다. 신규 `$bghit` 경로 — 러너 앵커 매칭 Bash 의 스텁에서 출력 경로를 뽑고 **그 경로와 정확히 일치하는** 후속 `Read` 결과에서 `VERIFY: PASS` 확인, `$besthit = max($lasthit, $bghit)`. **완화가 아니라 경로 추가**다: 백그라운드 Bash 도 러너 앵커를 먼저 통과해야 하고, 경로 일치·출처 구속이 걸려 임의 파일 `Read` 로는 열리지 않으며, staleness 는 `Read` 가 아닌 **러너 Bash 인덱스** 기준이라 "기동→코드수정→Read" 를 stale 로 잡는다. 필수 가드 2종 — `select(test(marker))` 선행(없으면 `null|split` 로 jq 가 죽어 **rc=2 fail-open = 게이트 무음 해제**) · `Read` 결과에도 `PARTIAL|FAIL` 부정토큰 검사(없으면 T10 이 잠근 위조 표면이 신규 경로에 무잠금 이식). deny 안내문도 원인을 구분한다 — 백그라운드가 감지됐는데 회수 기록이 없으면 회수할 경로를 알려주고, 아니면 포그라운드 `timeout` 지침을 준다. **동종 계보 3번째**(멀티라인 러너·`tests/run-all.sh` 앵커 누락에 이어 "정직한 실행이 앵커 밖")이며, 앞선 둘과 달리 명령 문자열이 아니라 **실행 모드**가 앵커 밖이었다. 이 FID 의 구현 커밋 자체가 **백그라운드 증거로 게이트가 열려** 통과했고, 실제 transcript differential(`$bghit` 무력화 시 rc 0→1)로 자기증명했다.
  - 독립 리뷰가 실제 결함 3건을 잡았다 — Phase B 1회차: `_EXEC_BG_PENDING_PATH` 를 `res=$(apply_lookback_rule …)` **서브셸 안**에서 설정해 부모로 전파되지 않아 원인 구분 안내가 **기능적으로 죽어 있었고**, 그걸 검사하던 테스트는 훅 **소스 문자열 grep** 이라 배선이 끊겨도 통과했다(gbrain 인사이트 "정적 grep 배선 검사는 동작 위임을 못 본다" 의 재현) → 부모 스코프 `_bg_pending_path()` 분리 + **behavioral 테스트**로 교체. Phase C: deny 안내가 stale 케이스에서 "Read 하면 인정됩니다" 라고 **과약속**해 안내 이행 후 재차단되는 BYPASS 스파이럴 조건 → `$lastedit` 정렬 · 러너 앵커 regex 3중 복제 drift 미잠금 → T25 로 고유성 잠금(한 곳만 바꿔도 FAIL).
  - 한계 명시 — 관측 발생 **1건**(R-1 마찰 104행은 `friction-log` 스키마상 원인 귀속 불가) · 잔여 위조 경로 1건(러너 실제 기동 후 완료 전 출력 경로 덮어쓰기 — 실효 완화는 "실제 기동 강제" 하나뿐이며, 신규 경로 최저가 위조는 도구 3회로 **기존 포그라운드 위조 1회보다 비싸다**) · 회수 경로는 `Read` 만 실측(`BashOutput` 등 미인식) · 스텁 문구 형식 의존(변경 시 rc=1 deny 방향 — 안전한 실패).

## [1.63.0] — 2026-08-07

### Added
- **`/doctor` — specops 설치·환경 건강 진단 (실사용 검증 20260807)** — `validate-structure.sh` 는 **플러그인 개발자용**이라 사용자 프로젝트의 `.specops/` 상태를 보는 층이 **0곳**이었다. 가장 위험한 공백은 **git hook 미설치** — `install-git-hooks.sh` 는 clone 마다 수동 1회이고, 미실행 시 2단 게이트가 **조용히 없다**(Claude Code PreToolUse 훅은 Cursor 등 타 도구 커밋에 발화하지 않음 — 계기: 44cd095 가 run-all 없이 나가 main 이 하루 red). read-only 4점검: git hook 2단 게이트(`core.hooksPath`+`pre-commit`+`pre-push`) · memory placeholder(판정은 `scan-enrich-placeholders.sh` **호출**로 재사용 — 중복 로직 금지, propagation edge 로 잠금) · 고아 FID · session-progress 정합. 항상 `exit 0`(조회 도구, 흐름 비차단) · `--json` 기계 판독 · `.specops` 부재 시 면제(5원칙 4 주권). NFR-2 실측 **0.16s / 2s 기준**(12.5배 여유) — `_chk_progress` 를 줄당 프로세스 스폰 0(순수 bash 문자열 연산)으로 구현한 결과다(A/B: 줄당 `printf|grep` 이면 **6.55s**). 어서션 19건, 변이 5종 전부 격추. 본 기능은 **specops 를 자기 lifecycle 로 11단계 완주시킨 실사용 검증**의 산출이다(게이트 우회 0회).
- **마찰 로그 집계 `gbrain-friction.sh` — 학습 루프 observe→distill 1단계 (20260807)** — `friction-log.jsonl` 이 `.specops/<FID>/` 마다 흩어져 **아무도 읽지 않았다**. 실측: 25개 파일 130행, 그중 **R-1(commit 전 verify) 89행 = 68%**, block 44건. 한 규칙이 23개 FID 에서 89번 울렸는데 그 신호로 바뀐 것이 0이었다 — 데이터가 없어서가 아니라 **집계가 없어서**다. 규칙별 행수·**FID수 분리**(한 FID 편중 vs 전역 패턴 구분)·severity 분포 + 증류 후보(기본 3회, Hermes 학습 루프의 "3회 이상 반복 → 증류" 차용). `/gbrain` **기본 출력**에 편입 — 별도 플래그 뒤로 숨기면 결함 원인(있는데 안 읽힘)이 그대로 재발한다. **게이트 자동 생성은 하지 않는다** — 클래스 B 정적 메타 규칙이 후보 4건 전부 오탐(4/4)으로 철회된 전례. 증류와 게이트 사이에는 사람 승인이 들어간다.
- **AC 필드 게이트 `check-ac-format.sh` — must 커버리지 fail-open 봉합 (OpenSpec 대조 갭분석 G1)** — `emit-context.sh` 의 **must AC 역방향 커버리지** 검사는 `**우선순위**: must` 가 있는 AC 만 대상으로 삼는다(코드 주석: "우선순위 필드가 아예 없는 구식/픽스처 AC 문서는 자연히 대상 0건(하위호환 fail-open)"). 즉 필드를 빠뜨리면 **검사가 무음으로 꺼진다** — 그런데 그 필드의 존재를 강제하는 층이 0곳이었다. 실측: AC 픽스처 **7개 중 6개가 우선순위 0건**(그 문서들에선 검사가 죽어 있었다). 게이트를 끄는 스위치가 무검증 상태였던 셈. HARD: 우선순위(값 `must`·`should`·`nice-to-have`)·Given/When/Then·골격 잔존·AC 토큰 0건 / WARN: 검증 방법·관련 FR·헤더형 AC 0건. 저작 지점(`specifying-ko`·`clarifying-ko`)까지 지시를 배선했다 — 게이트만 두면 모델이 AC 를 쓴 뒤 **dispatch 직전에야** hard block 을 만난다(클래스 A 의 거울상).
- **`hardgate_classified` 메타 규칙 — 결함 클래스 A 재발 구조적 차단 (구현 정합성 개선 20260806)** — 20260806 감사에서 **동일 클래스 결함 9건**이 나왔다: SKILL.md 가 HARD 를 선언하는데 그것을 검사하는 구현이 0곳(foundation manifest·재사용 게이트·회귀 AC·advisor 협의·DAST 소유확인·브랜치 삭제·Phase B/C 존재·화면 8섹션·analyzing baseline). **개별 수정만으로는 다음에 또 나온다** — 선언 시점에 결정을 강제하는 규칙이 필요하다. `validate-structure` 에 신규 검사: `<HARD-GATE>` 형식 블록을 가진 skill 은 그 게이트를 **반드시 분류**해야 한다 — ① `판정 SoT = <스크립트>`(기계 판정, **스크립트 실재도 함께 검사**해 dangling 인용 차단) 또는 ② `기계화 불가`/`대화 게이트`(사유 명시). 둘 다 없으면 FAIL — "선언만 하고 구현 여부를 결정하지 않은" 상태를 금지한다. 도입 즉시 **미분류 4건 적발**(brainstorming·clarifying·improve-arch·specifying) 후 전부 분류: 3건은 행위 금지·대화 승인이라 기계화 불가로 명시(후속 관문이 우회를 어떻게 좁히는지 함께 기록), clarifying 은 **부분 기계화**(foundation 스택 축만 `check-stack-decided.sh`)로 분류. 테스트 3건 — T-hg.b 는 분류 문구를 실제로 지워 적발을 확인하는 **mutation 내장** 테스트다.
- **골격 예시 소비처 계약 잠금 (클래스 B 재발 방지 — 정적 메타 규칙은 의도적으로 미채택)** — 클래스 A 처럼 정적 메타 규칙을 만들려다 **실측이 제안을 뒤집었다**: "실값 행" 휴리스틱으로 템플릿 22종을 스캔하니 후보 4건이 나왔는데 **전부 오탐**이었다(DESIGN.md 색상 `#______`·SKILL.md `{{...}}`·dispatch-context 5원칙 설명표·decisions `(예시)` 접두 — 정상). placeholder 형식이 **4가지**라 정적 판별이 안 되고, 진짜 성질은 "기계가 프로젝트 데이터로 읽는가" 라는 **의미론**이다 — 규칙화하면 오탐 생성기가 된다. 대신 **소비처마다 제외 규칙을 두는 현행 방식**(클래스 A 를 관문에서 잡은 것과 동일 원리)을 유지하고, 그 규칙들이 **조용히 사라지지 않도록** 한곳에서 잠갔다: `check-decisions-ledger`(`(예시)` 접두) · `check-fr-table`(`TBD`) · `scan-enrich-placeholders`(`specops:example`) · `screens-overview` 빈 fence. 새 소비처가 생기면 이 테스트에 행을 추가하는 것이 규약이다. 테스트 4건, 각 소비처 mutation 으로 비-vacuous 확인.
- **유지보수 baseline 산출물 게이트 — 데이터 안전망 무음 해제 봉합** — 클래스 A 9번째 인스턴스. `analyzing-ko` HARD-GATE 는 "두 산출물 사용자 검토 통과 전 specifying 금지" 인데 **산출물 존재 자체를 검사하는 층이 0곳**이었다(실측: 유지보수 FID 가 analyzing 산출물 0개로 `emit-context` 통과 → 구현). 2차 피해가 크다 — `check-regression-ac` 의 **스키마 override 판정이 `current-state.md` 를 읽으므로**, 파일이 없으면 `need_r2=0` 이 되어 **파괴적 스키마 변경에도 AC-R-2(데이터 보존)가 요구되지 않는다**(안전망 무음 해제). AC-R-1 도 baseline 없이는 "무엇을 보존하는지" 근거가 없다. 신규 `check-maintain-baseline.sh` 를 `emit-context` 에 배선 — 두 산출물 존재 + placeholder 잔존 시 미채움 판정(파일만 만들고 통과 차단). `§유형≠유지보수`·spec 부재는 skip/fail-open. HARD-GATE 본문에 **판정 분리**를 명시했다(산출물 존재·채움 = 기계 / 사용자 검토 = 대화 게이트). 테스트 9건, mutation 비-vacuous.

### Fixed
- **실사용 검증에서 드러난 게이트 자체 결함 6건 (20260807)** — specops 를 자기 lifecycle 로 완주시키자 게이트 자신이 부러진 곳이 나왔다. **6건 전부 합성 픽스처로는 안 나왔고 실제 문서를 쓰고·실제로 커밋하고·실제 CI 를 돌려야 보였다.**
  1. `check-ac-format` **골격 판정 오탐** — `` `<placeholder>` `` 를 **언급하는** 정상 문장을 골격으로 오판해 dispatch 를 막았다. 부분 매칭(`<...>`)을 앵커드(`^<...>$`)로 조이고 백틱 코드스팬을 벗겨낸다. 오탐보다 미탐을 택했다(클래스 B 교훈 — 과탐지는 정상 문서를 막아 게이트 신뢰를 깎는다).
  2. `_infer_commit_task` 가 **명시 선언을 무시** — `Task:...|T[0-9]+` 교대를 한 번에 스캔해 문서 순서상 먼저 나온 쪽을 집었다. 제목 "출력층 (T1~T4 집약)" + 본문 `Task: T4` 인 커밋이 T1 으로 오인돼, **훅이 deny 메시지로 직접 안내한 receipt 탈출구가 실제로는 열리지 않았다.**
  3. `test-pretool` T2 의 **`CLAUDE_PROJECT_DIR` 격리 누락** — 형제 T1·T2b·T2c·T2d 는 전부 격리했는데 T2 만 빠져 실 repo 루트에서 돌았다. 훅이 repo 의 **실제 활성 FID** 를 해석하므로 lifecycle 을 돌리는 순간 red 가 된다.
  4. `test-start-lite-doc` T13 의 **하드코딩 카운트 지뢰** — `grep -q '"count":23'` 는 커맨드가 늘 때마다 **반드시** 터지고(실측: `/doctor` 추가 시 차단), 카테고리 무범위 substring 이라 **templates 가 23 이어도 오탐 통과**했다. baseline 값 ↔ `ls commands/*.md` 실측 대조로 교체.
  5. `_parse_numbered` 의 **awk 로케일 의존** — `index($0,":")` 단위가 awk(BWK, macOS)=**바이트** vs gawk(UTF-8, Linux)=**문자**로 갈린다. 한글은 3바이트라 같은 문자열이 102 vs 40 이 되고, 픽스처가 하필 **경계 40 에 정확히** 걸렸다. `main` 이 3커밋 연속 CI red 였는데 **로컬 게이트가 전부 macOS 라 아무도 못 봤다.** `LC_ALL=C` 로 단위 고정 + 회귀 락 2종(배선 grep · PATH 에 gawk 심링크를 끼워 **awk 를 실제 교체**해 Linux 거동 재현).
  6. **화면 껍데기 backstop 이 현재 FID 범위로 스코프되지 않는다** — 무관한 기존 `screens/login.md` 가 매 verify 마다 경고를 낸다. 규약상 비차단이라 **미수정**, evidence 에 관측만 기록.
- **`gbrain` confidence 기록률 6% 의 근본 원인 + 미기재 순위 역전** — `learnings.jsonl` 167건 중 confidence 기재 10건(6%)이고 그마저 **2026-06-29~30 이틀에 몰려** 있었다. 원인은 모델이 게을러서가 아니라 **문서화된 호출 예시 4곳이 전부 `--confidence` 를 빼고 있어서**다 — 모델은 예시를 복사한다. 2차 결함: `gbrain-recall` 의 동점 가중치가 `high 3 · medium 2 · low 1 · **미기재 0**` 이라 저자가 "확신 낮음"이라 **명시한** 인사이트가 아무 평가도 없는 인사이트보다 위로 올라갔다(코퍼스 94%가 미기재). **평가 부재는 낮은 평가가 아니다** → 미기재를 `low` 와 동급으로.

### Docs
- **경쟁 프로젝트 소스 대조 분석 2건** — 문서·검색이 아니라 **소스 clone 후 실측**으로 작성(인용은 커밋 고정). `docs/speckit-repositioning-study.md`(spec-kit@81d5cdb): 훅 이식은 **가능**하다(`events.py` + `CANONICAL_TO_NATIVE` 가 `.claude/settings.json` 에 네이티브 훅을 쓴다 — 직전 판단 정정). 다만 유지비 절감 근거는 실측으로 철회 — 순 감축 1.2~2.2k = **생산 코드 19,298줄의 6~11%**(45k 헤드라인은 테스트 18.1k 포함). `docs/openspec-gap-analysis.md`(OpenSpec@d578896): 축이 직교한다 — OpenSpec 은 스펙 **내용**을 검증(validator 773줄·규칙 ~30), specops 는 **프로세스**를 강제(훅 deny). 갭 6건 우선순위화.

## [1.62.0] — 2026-08-06

### Changed
- **`§lite` FID 의 Phase B/C 생략을 하드 차단으로 승격 (lite 검토 20260806)** — `review-presence` 관측을 warn-first 로 도입한 이유는 소급 영향이었다(전체 FID 20건 중 **7건**이 무리뷰 → 즉시 하드화 시 35% 소급 FAIL). 그런데 lite 를 따로 재보니 **`§lite` FID 는 실측 0건**이었다(v1.60 도입 직후). 그리고 lite 는 clarify·plan 을 **이미 뺀** 모드라 **Phase B/C 가 남은 유일한 리뷰층**이다 — 여기서도 B/C 가 사라지면 lite 는 `spec → implement → verify` 로 외부 리뷰가 0 이 된다. 즉 **"가장 필요한 곳"과 "소급 비용이 가장 싼 곳"이 일치**한다. `§lite` 만 rc=1(차단)로 올리고 비-lite 는 warn 유지(기존 계약 무손상). `run-verification` 이 rc 를 판정에 반영하도록 배선 — 종전엔 rc 를 버려 §lite 차단이 관문에 도달하지 못했다(T10.d 로 잠금). E2E: §lite → `VERIFY: FAIL review-presence`, 비-lite → `WARN` + `VERIFY: PASS` 동시 실증. 테스트 4건(T10.a~d), mutation 비-vacuous.

### Added
- **가정 다이제스트 결정론적 집계 — 무인 모드의 유일한 확인점 (`/start-all-auto` 분석 20260806)** — `/start-all-auto` 는 clarify BLOCKING 을 best-guess 로 자동 답하고 `status: ASSUMED` 로 기록한다. 사용자가 그 가정들을 보는 **유일한 지점이 batch PR 게이트의 다이제스트**다 — 나머지 확인은 전부 자동 통과한다. 그런데 집계가 **모델 재량**이라 누락·과소보고를 잡는 층이 0곳이었다(`batch-state`·`pretool` 어디에도 검사 없음 — 실측). 누락되면 사용자는 무엇이 자기 대신 결정됐는지 모른 채 batch PR 을 승인한다 — 무인 모드를 수용 가능하게 만드는 단 하나의 게이트가 내용을 잃는다(5원칙 4 주권). 신규 `collect-assumptions.sh` 가 queue.md 의 **IMPL_DONE FID 전체**를 훑어 ① `clarifications.md` 의 `status: ASSUMED` Q-block ② `spec.md` 의 `**자동 결정 화면**`·`**자동 결정 인터페이스**` 를 집계 — **과소보고가 구조적으로 불가능**해진다. `RESOLVED`(사용자가 정함)·비-IMPL_DONE FID 는 제외, **0건도 명시 보고**("0건"과 "집계 안 함"은 다르다). `/start-all` 에도 배선 — §auto 가 아니어도 Phase 2.5 가 화면·IF 를 대화 승인 없이 반영하는 경로가 있다. 테스트 8건, mutation 비-vacuous.

### Fixed
- **`/start-all` Phase 2 plan-review 의 Critical 판정이 산문뿐 — 무인 오판 표면 (`/start-all-auto` 분석 20260806)** — Phase 2.5-D(design-review)는 `^Critical:[[:space:]]*[1-9]` **기계 grep** 으로 Critical 을 판정하는데, Phase 2(plan-review)는 "Critical≥1" **산문 판단**뿐이었다. `plan-reviewer-ko` 도 동일 포맷(`Critical: <N>건`)을 출력하므로 기계화가 가능한 자리다. §auto 무인에서는 사람이 없어, 모델이 Critical 수를 오판하면 **Critical plan 이 그대로 자동통과**한다. 두 리뷰 축이 **같은 패턴**을 쓰도록 고정했다(드리프트 방지 테스트 T13.b 로 2곳 이상 존재를 잠금). 테스트 2건, mutation 비-vacuous.
- **foundation 재사용 게이트의 태스크 원천 불일치 — 미검사 태스크가 조용히 통과 (`/start-all-auto` 분석 20260806)** — 게이트는 `## 태스크 N:` **마크다운 절**만 순회하는데, `emit-context` 가 실제로 dispatch 하는 태스크 원천은 **YAML DAG** 다. 두 원천이 어긋나면(YAML 2 태스크 · 마크다운 절 1개) **나머지 태스크는 검사 자체를 안 받고 통과**한다(실측 확인). 무인(`/start-all-auto`)에서는 사람이 눈으로 못 잡으므로 미선언 태스크가 그대로 구현에 들어간다. YAML 태스크 id 수와 절 수를 대조해 미검사 태스크를 지목하도록 보강 — `emit-context` 와 **동일 SoT**(YAML)를 기준으로 삼는다. 테스트 2건(T11.a·b), mutation 비-vacuous.

### Added
- **TDD RED 증거 관측 (warn-only 1단계)** — `record-task-receipt.sh` 는 `test_command` 가 **PASS 일 때만** receipt 를 남긴다. 즉 GREEN 은 증명되지만 **"구현 전에 실패했는가"(RED)** 는 아무도 안 봤다 — 빠지는 것은 **공허한 테스트**(구현 없이도 통과하는 테스트)다. 근거는 이론이 아니다: 20260806 세션에서 **작성자 본인의 테스트가 공허하게 통과한 사례가 7건**이었고 전부 mutation 에서만 드러났다(헬퍼 정의 순서·느슨한 grep 2회·h2 헤더 매칭·예시행 오탐·OR 조건 축 미격리 등). 신규 `check-tdd-red.sh` 가 transcript 에서 같은 `test_command` 의 결과를 시간 순으로 보고 **FAIL 이 첫 PASS 보다 앞서면** RED 로 인정한다(PASS→FAIL 은 "구현 후 깨짐" 이라 불인정, 타 명령 FAIL 불인정). **★ 판정은 `is_error` 가 아니라 내용 토큰 기반** — 실측: 본 세션 `tool_result` 658건 중 `FAIL=` 를 담은 **187건의 `is_error` 가 전부 false**였다. 실패한 테스트 실행은 `is_error` 를 세우지 않는다. advisor 게이트(`server_tool_use`)와 같은 교훈으로, 형태를 추측했다면 영구 0-hit 이 됐다. bash 하네스(`FAIL=[1-9]`)·pytest(`N failed`)·go(`^FAIL`) 토큰 인식. `record-task-receipt` 가 결과를 receipt 의 `tdd_red: observed|absent|unknown` 필드로 남긴다 — **커밋을 막지 않는다**(판정 불가가 흔함: 이전 세션 실행·명령 문자열 변형. 차단 전환 시 바꿀 지점은 호출자의 비차단 처리). E2E 로 `observed`/`absent` 양쪽 모두 receipt 정상 기록 실증. 테스트 9건, mutation(순서 판정 제거 → T3 재현) 비-vacuous, `propagation-matrix` `tdd-red-observation` 락.

## [1.61.0] — 2026-08-06

### Added
- **`/start-lite` · `/maintain-lite`** — clarify·plan ceremony만 생략하는 경량 Lifecycle 진입. 화면(Step 5.5)/IF(5.6)·Phase B/C·verify·AC-R-1은 풀과 동일. `/maintain-lite`는 analyzing-mini. strict 신호 시 `/start`·`/maintain` 승격. NL로 lite 추론 금지(슬래시 전용).

### Changed
- **start-all Phase 3 복구 (per-FR)** — batch-end-loaded(전 FR A 후 B/C 1회)를 되돌림. Phase 3는 다시 FR마다 `implementing`(FID end-loaded B/C) → verify → request/receive(또는 end-loaded skip). Phase 2.5·plan-reviewer defer는 유지.
- **start-all Phase 1 plan-reviewer batch defer** — FR마다 ★플랜 검사관을 빼고(`DEFERRED`), 전 `PLAN_DONE` 후 Phase 2에서 `plan-reviewer-ko` **1회** + `batch-plan-digest.sh` 짧은 표 → [y/n]. `/start`·foundation은 per-FID 리뷰 유지. per-FR 외부 critic도 batch로 이전/SKIP.
- **implementing end-loaded 리뷰 (기본, `/start`·`/start-all` FR)** — 태스크별 A→B→C를 **A만 wave → FID 말미 B 1회 + C 1회**로 전환(`review_mode: end-loaded`). 레거시 `per-task`. requesting은 B/C 산출 시 `review-skip.md` skip.

- **2단 git hook 게이트 (`.githooks/` + `install-git-hooks.sh`)** — `pre-commit` = validate-structure + check-propagation(~5s) · `pre-push` = `run-all.sh` 전체(~195s). 계기: `44cd095` revert 가 `run-all` 없이 나가 `main` 이 하루 red — **Claude Code PreToolUse 훅(R-1)은 Cursor 등 다른 도구의 커밋에 발화하지 않아** 도구 무관 게이트는 git hook 층뿐이다. 커밋마다 195s 를 걸면 `--no-verify` 관성(= 이 repo 가 BYPASS 로 겪은 실패 모드)이 생기므로 비용을 2단으로 분리했다. 게이트 스크립트 부재 repo 는 자동 면제(월권 금지), 탈출구는 `--no-verify`(5원칙 4). `core.hooksPath` 는 버전관리 대상이 아니라 clone 마다 1회 설치가 필요하다. 테스트 10건 — GH-8 은 **44cd095 파손 리비전을 실제로 복원해 pre-commit 이 차단함을 실증**한다.

### Fixed
- **`gbrain-append` 만 FID 형식 무검증 — 학습 원장 오염 (유틸 스캔 20260806)** — repo 전 스크립트가 FID 를 `^[0-9]{8}-[a-z0-9-]+$` 로 검증하는데(`session-progress-append`·`show-fid-status`·`record-metric`·`record-task-receipt`·`promote-validate`) `gbrain-append.sh` 만 무검증이었다. 실측: 실 `learnings.jsonl` 에 **형식 위배 5건**(`audit-20260710` 등) 적재 — `/gbrain --fid <FID>` 필터·FID별 환류 조회가 조용히 어긋난다. 동일 패턴 검증 추가(빈값=자유작업 인사이트는 허용). 레거시 픽스처(`fid-A`/`fid-B`)를 규약 형식으로 갱신. 테스트 4건(T5.a~d), mutation 비-vacuous.
- **화면 껍데기 판정이 자기보고였다 — 필수 8섹션 실채움 검사 (`specifying-ko` 정밀분석 20260806)** — `design-screen.sh --check` 는 `specops:screen-placeholder` **마커 유무만** 봤다. 그런데 그 마커는 *"실제 내용으로 채우면 이 줄을 삭제한다"* 규약 — 즉 **모델이 스스로 지워 "채웠다"고 선언**하는 자기보고다. `specifying-ko` Step 5.5 와 `/design-screen(s)` 가 선언한 **필수 8섹션**(목적·Layout·Components·States·Interactions·필드 정의표·데이터 소스·에러 메시지)이 실제로 있는지 검사하는 층은 0곳이라, **마커만 지우면 반쯤 빈 화면이 `FILLED` 로 통과**했다(Phase 2.5-A 재사용 판정·verify 화면 계약 대조가 이를 완성 화면으로 읽는다). `screen_missing_sections()` 추가 — 헤더 존재 **+ 본문 비어 있지 않음**을 요구하고(헤더만 복사 방지) 누락 섹션명을 지목한다. 조건부 4섹션(RBAC·반응형·접근성·진입/이탈)은 "미해당 시 넣지 않는다" 규약이라 대상 제외, `.html` 은 마커 판정만 유지. 기존 AC-12("마커가 유일 기준")는 **본문 리터럴 비의존**이 취지였고 그 취지는 보존된다 — 리터럴이 남아 있어도 섹션만 갖추면 통과(T4.d). 레거시 1섹션 stub 픽스처 2건은 확장된 계약에 맞춰 갱신. 테스트 5건(T6.a~e), mutation 비-vacuous.
- **Phase B/C 수행 존재 관측 (warn-only 1단계 — 패턴 A 스캔 20260806)** — skill 은 "Phase B/C 생략 금지" 를 여러 곳에서 HARD 로 선언(`§lite 불변`·risk-profile allowlist·`implementing-ko` 리뷰 규약)하는데, `check-review-audit.sh` 는 **정합 검사**(reviews ↔ dispatch-log)지 **존재 검사**가 아니라 **리뷰를 0회 하면 검사 대상 자체가 없어 `SKIP` rc=0 으로 통과**한다(실측). 즉 선언에 대응하는 관측조차 없었다. 신규 `check-review-presence.sh` 를 `run-verification` 에 배선 — `tasks.md` 보유(=구현 도달) FID 에서 `reviews/*-B-*`·`*-C-*` 수행 흔적을 확인하고 없으면 stderr WARN + evidence.md 기록 + friction-log 적재. **차단하지 않는다**: 이 fail-open 은 의도된 설계였고("산출물 부재는 SKIP — 무관 repo·초기 FID 월권 0"), 즉시 하드화하면 본 repo 기존 FID **20건 중 7건(35%)이 소급 FAIL**(실측)이라 1단계는 빈도 관측만 한다 — 전환 시 바꿀 계약이 이 `exit 0` 이다. FAIL 라운드의 `-feedback.md` 도 수행 증거로 인정. E2E 로 `WARN` 출력 + `VERIFY: PASS` 동시 성립 실증. 테스트 10건 — 그중 **T3b 는 mutation 이 적발한 공허 통과의 산물**(B·C 를 한 케이스로만 검사하면 한 축을 무력화해도 다른 축이 miss 를 채워 전부 통과 — 축별 격리 케이스 추가로 두 축 각각 mutation 재현).
- **브랜치 삭제 게이트가 모델 자기세팅 변수였다 — 커밋 소실 표면 (패턴 A 타겟 스캔 20260806)** — `finishing-a-development-branch-ko` 의 핵심 HARD GATE 가 `[ "$MERGE_CONFIRMED_BY_GH" = "true" ]` 인데 **이 변수를 모델이 스스로 세팅**한다. gh 가 실제로 `MERGED` 를 반환했는지 검증하는 층이 0곳이었고, `git branch -D`·`git worktree remove`·`git push --delete` 는 pretool 훅 관할 밖(R-1/R-2 는 commit·PR 만 본다)이라 **미머지 브랜치 삭제 시 커밋이 소실**될 수 있었다 — 이번 세션 발견 중 유일하게 결과가 **비가역 데이터 손실**인 건. 신규 `check-branch-deletable.sh` 가 근거 2종으로 판정: ① git 조상(`merge-base --is-ancestor` — 일반 merge) ② gh PR `state=MERGED`(squash/rebase merge 는 조상이 아니므로 이것만이 근거). **fail-CLOSED** — gh 미설치·PR 없음·조회 실패 등 판정 불가는 **금지**로 처리한다(다른 게이트의 fail-open 과 반대인 이유는 안전한 쪽이 "안 지움" 이기 때문). base·현재 체크아웃 브랜치는 거부(자기 발등 방지). 테스트 9건(완전머지·미머지·squash±gh증거·gh OPEN·부재·사용오류·main·skill 배선), mutation(fail-CLOSED 제거 → T2·T6 재현) 비-vacuous.
- **`/start-all` 이 placeholder FR 을 실 기능으로 세던 문제 (templates 전수 스캔 20260806)** — Phase 0 는 `grep -E '^\| FR-[0-9]+ \|'` 로 FR 을 기계 파싱하고 **"행 0건이면 중단"** 만 검사한다. 그런데 `templates/requirements.md` 는 `| FR-1 | <한 줄> | M1 | must |` **placeholder 행 3건**을 담고 배포되고, init 의 `_seed_fr_row` 는 PRD 마일스톤이 비면 그 행을 그대로 둔다 → **사용자가 FR 을 하나도 안 썼는데 batch 가 3개 기능을 구현하겠다며 진입**하고 Phase 1 이 specifying-ko 에 넘기는 "FR 원문" 이 `<한 줄>` 이 된다. 기존 가드는 *비어 있음*은 잡지만 *의미 없음*은 못 잡았다. 신규 `check-fr-table.sh`(rc 0=실 FR≥1 · 1=실 FR 0건 · 2=파일 부재)가 빈칸·`<...>`·`TBD`/`(미정)` 설명을 실 FR 에서 제외하고, 혼재 시 placeholder id 를 지목해 batch 대상 제외를 안내한다. `start-all.md` Phase 0 배선. 실측: 골격 템플릿 그대로면 `실 FR 0건 (placeholder 3건: FR-1, FR-2, FR-3)`. 테스트 8건, mutation 비-vacuous.
- **`api-spec-consumer` 예시 표도 동일 마커 처리 (자매 파일)** — `verifying-evidence-ko` 가 소비 IF 축을 이 표와 대조하므로 예시 잔존 시 **유령 외부 API 가 계약으로 읽힌다**. `specops:example` 블록으로 감쌈.
- **`api-spec`·`data-model` 템플릿의 전자상거래 예시 표 — 유령 스키마가 설계 계약이 되던 문제 (design 계열 정밀분석 3라운드 20260806)** — 두 템플릿이 `/v1/users/:id`·`users`/`orders`/`products` **예시 표를 경고 한 줄 없이** 담고 배포된다. 그리고 이 예시는 placeholder(`<...>`)가 아니라 **완성된 실값처럼 보여서** 유일한 기계 검사인 `scan-enrich-placeholders.sh` 가 **구조적으로 못 봤다**(실측 검출 0). 두 문서는 구현의 **설계 계약**이고 `/design-interface` Step 3 는 `screens-overview` 와 같은 **append 경로**라, 전자상거래가 아닌 프로젝트에 유령 스키마가 계약으로 남아 `design-reviewer-ko` 정합 검사·`verifying-evidence-ko` memory 동기화 점검이 이를 **실 계약으로 읽는다**. 예시를 `<!-- specops:example:start -->`…`:end -->` 로 감싸 **기계 검출 가능**하게 만들고 스캐너가 잔존 시 미채움 판정하도록 확장(기존 배선 재사용 — e2e V21 이 이미 `.specops/memory/*.md` 를 이 스캐너로 검사). 템플릿 경고 + `/init-project` Phase 11 enrich 에 "마커째 삭제" 배선. 실측: 부트스트랩 산출물에서 `api-spec.md:28`·`data-model.md:76` 검출 확인. 테스트 9건, mutation 비-vacuous. **동일 클래스 3연속**(decisions.md → screens-overview.md → api-spec/data-model) — 골격에 그럴듯한 예시를 넣으면 "비어 있음"과 "채워짐"이 구별되지 않는다.
- **`screens-overview` 골격의 유령 화면 — 화면 목록 마스터가 없는 파일을 가리켰다 (design 계열 정밀분석 20260806)** — 템플릿 §1 fence 가 `home`·`login`·`dashboard` **예시 3행**을 담은 채 배포됐다. `/init-project` Phase 7 은 fence 를 통째로 교체하므로 무해하지만, **`/design-screen` 은 append 경로**라 예시가 남는다 → 존재하지 않는 `screens/home.md`·`dashboard.md` 를 가리키는 행이 마스터에 잔존(실측: 첫 화면 1건 생성 후 유령 참조 **2건**). Phase 2.5-A UI 표면 검출·`design-reviewer-ko` 정합 검사가 이 유령을 실 화면으로 읽는다 — `decisions.md` 예시 행과 **동일 클래스**. fence 를 **빈 상태**로 배포하고(= "아직 화면 없음" 이 진실) 작성 형식은 파이프 없는 샘플 표기로 분리했다(파이프로 시작하는 샘플 줄은 도구가 실제 행으로 오인 — T19.a 회귀로 실증). 부수: `design-screen.sh` 가 중복 이름으로 **행을 추가하지 않았는데도** "screens-overview.md 갱신됨" 을 출력하던 **거짓 보고** 수정(이제 "이미 등록된 이름 — 기존 행 유지" 명시). 테스트 4건(T10.a~c·T11), mutation 비-vacuous.
- **DAST 소유확인 ACK 게이트 — 법적 안전장치가 산문뿐이었다 (`/security-scan` 정밀분석 20260806)** — 소유확인(`본인 소유 서버입니까? [y/N]`)은 command 산문에만 있어 `dast-scan.sh` 를 **직접 실행하면 확인 없이 능동 스캔이 나갔다**(실측: ACK 없이 docker ZAP 분기가 localhost 대상 실제 실행됨 — 무단 스캔은 불법). 실 스캔 경로에 `SPECOPS_DAST_ACK=1` 을 요구(없으면 exit 2 + 소유 고지)하고, command 는 사용자 `[y]` 승인 **후에만** env 를 부여하도록 배선. `NO_RUN` dry 는 실 스캔이 아니므로 면제(테스트·CI 결정성 유지). 부수: **self-config 모드 FID 미정의** 봉합 — lifecycle 밖 온디맨드라 진행 FID 가 없는데 산출 경로가 `.specops/<FID>/` 로만 적혀 있어 임의 슬러그·무관 FID 귀속 표면이었다 → `<YYYYMMDD>-self-config-audit` 고정 규칙 명시. 그 외 실측 견고 확인: SAST self-check 양성(crit=1 high=2)·음성(0)·단일 파일·자기 repo(crit=0) 4형태 + 기존 스위트 4종(security-scan 5 · dast 2 · self-config-collect 5 · agents) 전부 GREEN. 테스트 4건(T-ack.a~d), mutation(게이트 무력화 → 실 스캔 재발) 비-vacuous.
- **`/promote` — analyzing 분기 검증 재실행 (정밀분석 20260806)** — `promote-validate.sh`(포맷·트래버설·mini-FID·already-promoted 판정)는 **command 레이어(Process 1)에만** 배선돼 있었다. 재개 세션·스킬 직접 호출로 `analyzing-ko` [promote-fid 분기]에 도달하는 경로엔 검증이 없어, `already-promoted`(spec.md 존재) FID 로 진행하면 specifying 유지보수 분기가 **진행 중 lifecycle 의 spec.md 를 덮어쓴다**. 분기 첫 동작으로 `promote-validate.sh` 재실행 + `REJECT:*` 시 중단을 명시(T9 락 — mutation 비-vacuous). 그 외 표면은 견고 확인: promote-validate 상태 전이 10 테스트 · `freework-resolve-fid` 종결 마커 오귀속 차단 7 테스트 · freework 필드 3단 fallback(files→git diff→git log) + 빈손 한계고백 · 오늘 추가된 `/maintain` 게이트(AC-R·라벨 정합·must 커버리지)가 promote 승격 흐름(유지보수 라벨)에도 그대로 적용된다.
- **must AC 역방향 커버리지 + §유형 라벨 정합 (`/maintain` 후속 20260806)** — ① `emit-context` 검증은 task→AC **한 방향**뿐이라(ac 배열 id 가 AC.md 에 존재), AC-R-1 을 채워 놓고 **어느 태스크에도 매핑하지 않으면 회귀 테스트가 영영 구현되지 않았다**. decomposing 산문("모든 must AC 가 최소 1 태스크에 매핑")의 teeth 로, `**우선순위**: must` 인 AC id 전부가 태스크 ac 배열 합집합에 있는지 dry-run 에서 검사(우선순위 필드 없는 구식 문서는 대상 0건 — 하위호환 fail-open). ② analyzing 마커(`합산 N줄 → 유지보수`)와 spec `§유형: trivial` 의 **다운그레이드 불일치**를 `check-regression-ac.sh` 가 차단 — 합산 >5 인데 trivial 라벨이면 AC-R-1 면제가 근거 없이 열린다(상향은 허용). AC 헤더 매칭을 h2/h3 겸용으로 확장(#209 완화 철학 정합) — 이 과정에서 T3.a 가 h2 픽스처의 "부재 FAIL" 로 **공허 통과**하던 것을 적발·정정(세션 6번째). T9 픽스처(trivial+override)는 analyzing 계약상 자기모순 조합이라 라벨 검사가 우선 차단하는 것으로 재정의(정정 후 AC-R-2 는 T7 이 잠금 — 우회 경로 없음). 테스트 5건(T3.a·b·T13·T14·T15), mutation 각각 비-vacuous.
- **회귀 AC(AC-R-1/AC-R-2) 게이트 기계화 — `/maintain` 의 존재 이유가 산문뿐이었다 (`/maintain` 정밀분석 20260806)** — specifying-ko 는 "유지보수 → AC-R-1 강제(스키마면 AC-R-2)" 를, 템플릿은 "evaluator 가 누락 시 `verdict=BLOCK`" 을 선언하는데 **검사 구현이 0곳**이었다 — 모델이 빠뜨리면 회귀 AC 없이 구현이 진행된다("새 기능이 이상함" 이 아니라 "**멀쩡하던 것이 깨짐**" 클래스). 신규 `check-regression-ac.sh` 를 `emit-context.sh`(구현 직전)에 배선: AC-R-1 필요조건 = `§유형: 유지보수`, AC-R-2 필요조건 = current-state.md 의 `스키마 override` 마커 — **둘은 독립**이라 trivial 이어도 파괴적 스키마면 AC-R-2 를 요구한다(데이터 안전은 라인수 면제 불가 — 템플릿 예외 계약 그대로). 템플릿이 AC-R 섹션을 **기본 포함**하므로 헤더 존재만으론 템플릿 복사로 뚫린다 — Given/When/Then 의 대괄호 placeholder 잔존을 미채움으로 판정(T3 잠금). 신규·trivial(비-override)·spec 부재는 skip/fail-open. 테스트 12건, mutation 비-vacuous, `propagation-matrix` `regression-ac-gate` 5자 락.
- **batch Step A/B/C ↔ RELEASE_READY 설계 충돌 — 정직한 `/start-all` 완주가 batch PR 에서 hard deny (`/start-all` 정밀분석 20260806)** — Phase 3 완료 Step A/B/C(security·integration·performance)는 batch 전체를 **1회** 실행하고 각 skill 은 호출된 **대표 FID 1곳**의 evidence.md 에만 verdict 를 남긴다. 그런데 v1.60 RELEASE_READY 는 `gh pr create` 시 ACTIVE batch 의 **전 IMPL_DONE FID** 각각에 이 3 게이트 = PASS|SKIP 을 요구한다 — 비대표 FID 는 전부 `MISSING` → NOT_READY → **hard deny**(인라인 BYPASS 불가). F1 과 동류의 "설계 간 충돌" 로, 테스트로 실증했다(T1: 정직한 batch 픽스처에서 비대표 FID `security=MISSING`). 신규 `record-batch-gate.sh <batch-dir> <gate> <PASS|SKIP> [근거]` 가 batch verdict 를 전 IMPL_DONE FID 의 evidence.md 로 전파한다 — **FAIL 은 전파 거부**(systematic-debugging 후 재실행이 정도), **SKIP 은 근거 필수**(skip-tracker CITED 규약), **멱등**(기존 섹션 보존 — 대표 FID 원본 포함), 섹션 포맷은 `skip::verdicts` 파서 계약 준수. `start-all.md` Step A/B/C 3곳에 배선. 테스트 8건, mutation(멱등 가드 제거 → T3·T4 재현) 비-vacuous, `propagation-matrix` `batch-gate-propagation` 4자 락.
- **foundation 기술스택 확정 게이트 — clarify 층 봉합 (20260806)** — `clarifying-ko` 의 "§유형=foundation + architecture placeholder → 기술 프레임워크 BLOCKING, RESOLVED 전 planning 진입 차단" 은 판정기를 만든 뒤에도 **호출이 산문 의무**로 남았다 — specify→clarify→plan 이 전부 대화라 스크립트가 반드시 지나는 관문이 없기 때문. 결정의 **증거**를 구현 직전 하드 관문(`emit-context.sh`)에서 재검하도록 신규 `check-stack-decided.sh` 를 배선했다. 증거 인정: ① `decisions.md` 스택 확정 행(clarifying HARD 규약상 RESOLVED→upsert 가 정규 경로) ② `clarifications.md` 의 스택 `RESOLVED` 기록(원장 upsert 누락 구제 — 경고 동반). **`status: ASSUMED` 는 결정이 아니므로 불인정.** 발동 조건은 §유형=foundation ∧ architecture 문서 존재 ∧ 그 문서에 raw placeholder 잔존 — placeholder 가 없으면 스택은 이미 문서로 확정된 것이라 skip(false-block 방지). spec.md 부재는 fail-open. 이로써 clarify 를 건너뛰어도 미확정 스택으로 구현에 진입할 수 없다. 테스트 10건, mutation 으로 발동 조건 무력화 시 3건 재현.
- **결정 원장 "확정값" 판정 기계화 — 골격의 예시 행이 BLOCKING 면제를 열던 문제 (20260806)** — `decisions.md` 소비 규칙(HARD)은 "확정값이 있는 주제는 BLOCKING 재질문 금지" 인데 판정이 **모델 눈대중**이었다. 그런데 `/init-project` Phase 10 이 만드는 원장 **골격에 예시 행이 들어 있다** — `| D-001 | (예시) UI 유무 | 있음 | init Phase11.5 | YYYY-MM-DD |`. 빈 원장이 "행이 있는 원장" 으로 보여서, 특히 **foundation 기술스택 BLOCKING 면제**가 근거 없이 열리면 미확정 스택으로 plan 에 진입한다. 신규 `check-decisions-ledger.sh`(`<주제 regex>` → 0=확정·1=미확정, `--list`)가 `(예시)` 접두 행·빈칸·`<...>` placeholder·`TBD`/`(미정)`/`해당없음` 류 무정보 값을 **모두 미확정**으로 판정한다. 소비처가 6곳(clarifying·specifying·start-all(-auto)·start-foundation·init-project)이라 판정을 한곳에 모았고, `clarifying-ko` BLOCKING 절에 "눈대중 금지 — 판정기로 확인" 을 배선했다. 실측: 부트스트랩 직후 원장에 프론트·백엔드·인증·UI 전부 `rc=1`(미확정), `--list` 빈 출력. 테스트 11건, mutation 으로 예시 행 제외 무력화 시 3건 재현.
- **CLI/라이브러리 foundation — 템플릿이 실패 형태로 유도하던 문제 (시나리오 검증 20260806)** — manifest 채움 판정을 엄격화한 뒤 CLI foundation 3개 형태를 실측했다. 결과: 모듈 행을 실제 CLI 모듈로 **교체**하거나 `해당 없음` 으로 **명시**하면 통과하고, 무관 행(라우팅·인증·레이아웃·DB)을 **템플릿 그대로 방치**하면 FAIL. 판정은 정확했지만 템플릿이 그 5행을 필수 구조처럼 제시하고 "지워도 된다"는 안내가 없어 **모델의 자연스러운 선택이 곧 실패 형태**였다. 완화가 아니라 안내로 해결 — 템플릿에 "웹/풀스택 기준 **예시**이며 해당 없는 행·항목은 **삭제**, placeholder 잔존 시 `VERIFY: FAIL`" 을 명시하고 `planning-ko` 산출 지시에도 동일 안내를 배선했다. 테스트 3건(T10 지침·T11 CLI 형태 PASS·T12 `해당 없음` PASS). T10 은 최초 느슨한 grep(`삭제|예시`)이 표 안의 `<import 예시>` 에 걸려 **공허하게 통과** — mutation 으로 적발 후 세 요소(행 삭제 허용·판정기 SoT·FAIL 귀결) 전부 요구하도록 강화했다.
- **foundation 재사용 게이트 소비측 기계화 (`/start-foundation` 정밀분석 20260806)** — 생산측(manifest 산출)을 기계화해도 소비측이 모델 재량이면 재사용 강제는 선언적 장식이다 — **공통부를 만들어 놓고 아무도 안 쓰는 상태가 조용히 통과**한다. `decomposing-ko` 계약("§유형≠foundation 이고 manifest 존재 시 각 task 에 `**재사용 foundation**` 또는 `**미재사용 근거**` 필수, 누락 시 implementing 호출 금지")을 신규 `check-foundation-reuse.sh` 로 옮기고 **`emit-context.sh`(Step 10b)에 배선** — dispatch 직전의 원자적 게이트라 실패가 곧 implementing 진입 차단이다(디스크 작성 0, 다른 검증과 동일 원자성). 빈 값·`<모듈명>` 류 placeholder 는 **미기재로 판정**(형식만 갖춘 통과 차단). `§유형=foundation`(생산자 자신)·manifest 부재(공통부 없는 프로젝트)·산출물 부재는 graceful skip. 테스트 10건(누락 지목·전건 누락·placeholder·빈 값·skip 3종·배선 2), mutation 비-vacuous.
- **foundation manifest 산출 게이트 기계화 — "침묵 무발동을 막으려는 게이트"가 침묵 무발동이었다 (`/start-foundation` 정밀분석 20260806)** — `verifying-evidence-ko` 는 이 게이트를 **HARD** 로 선언하고 근거까지 적어 뒀다("생산은 planning-ko 산문 지시뿐이라 verify 가 실제 산출물을 확인하지 않으면 후속 `/start` 재사용 게이트가 침묵 무발동한다"). 그런데 `run-verification.sh`·`release-ready.sh`·DAG 스크립트 **어디에도 구현이 없었다** — 모델이 체크리스트를 건너뛰면 그대로 통과. 신규 `check-foundation-manifest.sh` 로 판정을 옮기고 `run-verification.sh` 에 배선했다(리뷰 감사와 동일 이유 — 실행-근거 게이트가 `VERIFY: PASS` 만 커밋·PR 면제로 인정하므로 이 축도 같은 관문을 통과해야 실효가 있다). **테스트 명령 0건 분기에도 배선** — review-audit 이 이미 봉합한 "NO COMMANDS 우회" 와 동일 구멍이 foundation 에 남아 있었다. 채움 판정은 구 산문의 `grep -q '<경로>'` **단일 토큰**(경로만 채우고 `<설명>`·`<import 예시>`·`<확정된 프레임워크>` 가 전부 남아도 통과)에서 placeholder SoT(`scan-enrich-placeholders.sh`)로 통일 — HTML 주석 헤더 제외 규칙도 함께 상속한다. `§유형≠foundation`·spec.md 부재는 graceful skip(fail-open). 테스트 9건(부재·채움·raw 템플릿·**부분 채움**·비-foundation·fail-open·주석·배선 2), mutation 비-vacuous, 임시 repo E2E 로 `VERIFY: FAIL foundation-manifest 미산출` 실증, `propagation-matrix` `foundation-manifest-gate` 5자 락.
- **enrich placeholder 스캐너가 HTML 주석 헤더를 오검출 — e2e V21 구조적 달성 불가 (정밀분석 20260806)** — 모든 specops 템플릿은 `<!-- OWNER_COMMAND: … -->`·`<!-- layer: … -->` 헤더를 갖는데, 이는 **지울 수 없는 구조 계약**이다. `scan-enrich-placeholders.sh` 의 패턴이 이를 원시 placeholder 로 세는 바람에 검출 0 을 요구하는 e2e **V21 이 무엇을 해도 통과할 수 없었다**(실측: 부트스트랩 산출물 163건 검출 중 **26건이 HTML 주석**). `/e2e-test` 가 수동 전용(run-all 비포함)이라 잠복해 있었다. 줄 단위가 아닌 **토큰 단위**로 주석을 제거해(주석 밖 실 placeholder 검출은 유지) 26건 → 0건. 테스트 T10.f(주석만 → clean)·T10.g(주석 제외 후 실 placeholder 검출 유지), mutation 비-vacuous.
- **Phase 11 보강 깊이 목록에 `PRD.md` 담당 부재 (정밀분석 20260806)** — e2e V21 은 `PRD.md` 를 **스캔 대상으로 지정**하는데, Phase 11 의 `깊게`·`얕게/스킵` **어느 목록에도 PRD.md 가 없었다** — 게이트는 검사하고 채우는 주체는 없는 상태(실측: 부트스트랩 직후 원시 `<TODO>` 10곳 잔존 — NFR·리스크·기술 스택). `깊게` 에 배정하되 **§1~2 는 Phase 4 확정분이라 보강이 건드리지 않는다**는 경계를 명시했다(사용자 응답 덮어쓰기 금지 규약과 정합). 테스트 T12.b(깊게 **불릿 항목**으로 존재 — 인접 줄의 다른 `PRD.md` 언급에 걸리는 느슨한 grep 은 공허 통과라 블록 파싱으로 강화)·T12.b2(얕게 중복 배정 금지)·T12.c(확정분 보존 경계).
- **`/init-project` PRD 6필드 무라벨 numbered list 오파싱 — 프로젝트 문서 전체 오염 (정밀분석 20260806)** — `_parse_numbered` 가 `[0-9]+\.[^:]*:` 를 **한 덩어리로** 요구해, 라벨 없는 `1. 사내 일정 관리` 형식이면 sub 가 통째로 실패하고 값에 `1. ` 가 그대로 남았다. 이 값은 `PRD.md §1` → `CLAUDE.md` → `README.md` → `requirements.md` FR 시드행(`| FR-1 | 4. 로그인 |`)까지 전파된다(실측 4파일). `_phase_4_count_filled` 는 "비어있지 않음"만 세므로 오파싱은 단답 fallback 도 깨우지 못하는 **silent garbage** 경로였다. 무라벨형은 Phase 0 이 stdin 으로 파이프하는 자연 형식이고 **repo 자체 테스트도 이 형식을 먹이고 있었다**(T1.a 등) — 기존 테스트가 파일 존재·개수만 검증해 값 오염을 전혀 못 봤다. 별개로, 라벨 길이가 무제한(`[^:]*:`)이라 값 중간에 콜론이 늦게 나오는 긴 문장은 콜론 앞 전체를 라벨로 오인해 잘라냈다(실측 60자 손실). ① 번호 접두는 **무조건** 제거 ② 라벨 제거는 콜론이 앞쪽(≤40바이트)일 때만 — 으로 분리했다(interval 정규식 `{1,40}` 은 구형 awk 비호환이라 `index()` 판정). 테스트: 단위 6건(T-pn.a~f) + E2E **값** 단언 4건(T24.a~d — 존재·개수가 아니라 파싱 결과를 본다), mutation 으로 구 구현 복원 시 6건 재현 확인.
- **batch 재개 키를 날짜 → `ACTIVE` 마커로 (M2 — 커맨드 전수 분석 20260806)** — `BATCH_ID = batch-<YYYYMMDD>` 는 **날짜가 곧 재개 키**여서, 같은 날 두 번째 `/start-all` 을 다른 `requirements.md` 로 돌리면 이전 batch 의 `queue.md` 를 재사용해 서로 다른 FR 집합이 한 큐에 뭉갰다(`ACTIVE` 마커는 PR 게이트 오발화만 막지 queue 혼입은 못 막는다). Phase 0 이 `.specops/batch-*/ACTIVE`(훅 `_batch_pr_gate` 와 동일 관용구)로 진행 중 batch 를 찾아 **1개면 재개 · 0개면 신규 `batch-<YYYYMMDD>-<HHMM>` 생성 · 2개 이상이면 사용자 선택 게이트**(자동 선택 금지 — 주권)로 분기한다. 같은 분 재실행은 `-2`,`-3` 접미로 회피. **하위호환**: 구 포맷 `batch-<YYYYMMDD>` 도 `ACTIVE` 가 있으면 그대로 재개되고 디렉토리명을 바꾸지 않는다 — 진행 중 batch 의 재개 경로·`feat/<BATCH_ID>` 브랜치가 갈라지지 않는다. 훅·`batch-state.sh` 는 `batch-*` 글롭과 디렉토리 인자만 쓰므로 id 포맷 비의존(게이트 동작 무변경). 테스트 6건(T12.a~f), mutation 비-vacuous, `propagation-matrix` `batch-id-active-resume` edge 락.
- **`§lite` × strict 승격 가드에 기계 teeth (H1 — 커맨드 전수 분석 20260806)** — `/start-lite`·`/maintain-lite` 의 "strict 신호면 `/start`로 승격" 은 `specifying-ko:122·131` 의 **산문(모델 키워드 판단)** 뿐이었다. lite 는 clarify·plan 을 **이미 건너뛴 뒤** decompose 에 도달하므로, 뒤늦게 strict 가 드러나도 되돌릴 게이트가 없었다(잃어버린 clarify·plan 은 스스로 돌아오지 않는다). `batch-state` 의 lite-skip 재검은 `/start-all` 경로만 지켜 단독 `/start-lite` 는 무방비였다. `risk-profile.sh compute` 가 `spec.md` 의 `**§lite**: true` 를 **스스로 감지**해(플래그 설계면 플래그 생략으로 우회되므로 self-detect) `effective=strict` 이면 `LITE-STRICT-GUARD` rc=3 을 낸다 — `decomposing-ko` Step 10c 가 이를 받아 implementing 진행을 막고 clarifying→planning 승격을 요구한다. `plan.md` 가 생기면 **자동 해제**(영구 차단 방지). 범위는 `§lite` 한정 — `§유형: trivial` 단독은 제외했다(`public_api` 가 "엔드포인트" 한 단어에 걸려 최빈 경로가 false-block 생성기가 된다). 주권 탈출구는 `SPECOPS_LITE_STRICT_OVERRIDE=1` + **사유 병기 필수**(`SPECOPS_GOVERNANCE_BYPASS` 규약 동형) — 모델이 쓸 수 있는 마커 파일은 자기발급 면제표가 되므로 채택하지 않았다. 강도는 `emit-context.sh` fail-fast 와 동급(**기계 탐지 + 체인 레벨 강제**이지 하드 차단 아님). 테스트 8건(T14~T20), mutation 비-vacuous, `propagation-matrix` `lite-strict-guard` edge 4자 락.
- **R-5 자기발급 면제표 봉합 — advisor 협의에 실호출 증거 요구** — 종전 R-5 는 `## N. Advisor 협의 기록` 에 data row 가 **있기만 하면** PASS 했다. 그 표는 모델이 스스로 쓰는 것이라, "advisor 와 협의했다" 자기보고를 검증하는 층이 0 이었다(R-1/R-2 가 verify 자기보고에 대해 이미 봉합한 것과 동일 클래스의 구멍). `governance-lib.sh:_advisor_exec_evidence` 신설 — 협의를 **주장**하면(data row 1+, `해당 없음` 아님) transcript 의 실호출 증거를 요구한다. advisor 는 서버사이드 도구라 일반 `tool_use`/`tool_result` 가 아니라 **`server_tool_use`(name=advisor) ↔ `advisor_tool_result`** 로 기록되므로(실측 확인 — 일반 tool_use 만 보는 검사는 영원히 0건) 이 형태를 `tool_use_id` 로 직접 join 하고, `is_error` 결과는 불인정한다. advisor 미연결 시의 **공식 fallback 인 `critic-ask.sh` 실행도 인정** — 불인정하면 정직한 미연결 세션이 위반으로 찍힌다. `해당 없음` 정직 선언(원칙 5 한계 고백)은 증거 불요로 통과. 판정 불가(transcript 부재·jq 실패·content 블록 0건)는 fail-open. 강도는 기존과 동일한 `Stop` 훅 warn — advisor 는 비용·latency 트레이드오프가 있어 hard block 대상이 아니다. 테스트 6건(T10.i~T10.n) 추가 + 의미가 바뀐 T10.a 갱신(구 픽스처는 실호출 없는 data row 였다), mutation 으로 비-vacuous 확인, 실제 세션 transcript 대조로 블록 형태 검증.
- **RELEASE_READY `crit_high` 오탐 — end-loaded 기본 흐름 PR 하드 차단 봉합** — `release-ready.sh`가 `reviews/`를 `grep -RqlE 'NEEDS_FIX|## 🔴 Critical'`로 스캔했는데, `code-reviewer-ko` 출력 템플릿은 **발견 0건이어도** `## 🔴 Critical` 헤딩과 `## 종합 판정` 3종 메뉴(READY_TO_MERGE·NEEDS_FIX·NEEDS_DISCUSSION)를 항상 찍는다 → 무조건 매치. 구제 조건은 session-progress 의 `/receive-review`·`수용` 토큰뿐인데 08-04에 기본값이 된 end-loaded 는 requesting 을 `review-skip.md`로 건너뛰어 그 줄이 생기지 않는다. 결과: 전 축 PASS 인데 `crit_high=UNRESOLVED_REVIEW` → strict FID·ACTIVE batch 브랜치에서 `gh pr create` hard deny(BYPASS 강요 → 관성 재발 경로). 모든 진입점이 `decomposing-ko:10c`를 지나 `risk-profile.json`을 갖고, spec 에 "엔드포인트" 한 단어만 있어도 `effective=strict`라 예외가 아닌 **일반 케이스**였다. 판정기를 (a) 🔴 절의 **실제 항목**(플레이스홀더 `<file>:<line>`·`없음` 제외) (b) `READY_TO_MERGE` 없이 `NEEDS_FIX`만 남은 **선택된 판정** 두 신호로 교체하고, 스캔 대상을 최종 판정물 `*-report.md`로 한정(해소된 과거 라운드가 남는 `-feedback.md` 제외). teeth 보존 — 실제 Critical 항목이 있으면 여전히 수용 흔적을 요구한다. 회귀 테스트 8건(RR-14·14b·15·16·17·18·19·20, RED 3 → GREEN 22) — 그중 **RR-20 은 훅 레벨 증상 실증**(strict risk-profile + end-loaded 산출물 → `gh pr create` allow, 구 grep 복원 mutation 시 보고된 deny 그대로 재현). `propagation-matrix` `review-verdict-contract` edge 로 템플릿↔판정기 드리프트 락.
- **계약 전파 edge 보강 — 토큰이 아니라 소비 문자열까지 락** — `batch-review-skip` edge 가 토큰만 요구해, 44cd095 revert 가 `start-all.md`에서 `risk-profile.json` 경로만 떨어뜨렸을 때 전파 스캔은 통과하고 T1.e 만 red 로 남았다. 해당 id 에 `commands/start-all.md`·`scripts/batch-state.sh` ~ `risk-profile.json` edge 를 추가(파손 리비전 대조로 FAIL 재현 확인)하고, 신규 `end-loaded-skip` id 로 end-loaded 리뷰 계약 4자(implementing `review_mode` → requesting Step 0 사유 → start-all Phase 3 축소 조건 → batch-state 재검) 전파를 락했다. 테스트 P7·P8 추가(mutation 비-vacuous), 35 edges. README 에 "소비처가 읽는 경로·필드명을 edge 에 포함" 규약 명문화.
- **`start-all` lite review-skip 조건의 `risk-profile.json` 경로 복원** — batch-end-loaded revert 가 명시 경로까지 함께 걷어내 `batch-state.sh`(그 파일을 계속 읽음)와 문서가 어긋났고 `test-screen-generation-gate` T1.e 가 FAIL(run-all 112 중 1)로 하루 방치됐다.

## [1.60.0] — 2026-08-04

### Added
- **검증 상태 머신 + 비용·수율 계측 (P0)** — `verification-state.sh`가 `NOT_RUN|PASS|PARTIAL|FAIL|WAIVED`(+조회 시 `STALE`)를 FID별 SoT로 기록한다. `record-metric.sh`가 `.specops/<FID>/metrics.jsonl`에 토큰·wall·retry·fallback·판정 식별자만 append(원문 거부). `run-verification`·BYPASS·risk-profile이 자동 계측한다.
- **태스크 receipt R-1 게이트 (P0)** — implement 중간 커밋은 FID 전체 verify 대신 `record-task-receipt.sh`/`check-task-receipt.sh`(staged⊆outputs·tree 신선·test_command hash·커밋 메시지 T#)로 연다. R-2(PR)는 receipt로 열리지 않는다.
- **RELEASE_READY 합성 판정 (P0→Wave B)** — verify·review-audit·security/integration/performance·reconcile·Critical/High를 AND 합성. Wave B에서 **strict FID 또는 ACTIVE batch 브랜치 PR**은 NOT_READY 시 hard deny, 그 외 warn-only. UNKNOWN(rc=2) fail-open.
- **위험 프로파일 limited-live (P1→Wave B)** — `risk-profile.sh`가 lite/standard/strict를 기록(`mode=live`). lite만 `reductions_allowed: ["batch-review-skip"]`(requesting/receiving skip). Phase B·TDD·verify·receipt 축소는 금지. `batch-state`가 allowlist·단일 태스크·사유를 재검.
- **Phase 2.5 화면→IF→design-reviewer (#243 계열)** — `/start-all` batch가 화면·인터페이스를 통합한 뒤 `design-reviewer-ko`(evaluator)로 무거운 설계 리뷰. Critical≥1은 §auto여도 정지, Important-only만 §auto 자동통과.
- **Wave C 관측·DX** — (1) R-1 deny 시 `git add&&git commit` compound 분리 안내 (2) `propagation-matrix.jsonl`+`check-propagation.sh` 계약 드리프트 스캔(run-all) (3) `phase=evaluator-degradation` 메트릭 배선 + Phase 2.5 수동 dogfood 체크리스트.

### Changed
- **init-project·start-all 프로세스 축소 + 결정 원장** — 온보딩/batch 중복 질문·단계를 줄이고 `.specops/memory/project-context.md`·`decisions.md`로 확정 스택을 전달한다.
- **review-skip lite 메타 검증** — skip 경로에 `risk-profile.json`·`batch-review-skip` allowlist·단일 태스크·비어 있지 않은 사유를 요구(남용 차단).

### Fixed
- **Wave A 거짓 안심 제거** — `check-review-audit`가 산문 tid만으로 PASS하던 구멍 봉쇄(경로·`B:tid`/`C:tid`·`## task-<tid>` 구조화만 인정). reconcile review=70은 `review-request.md`/`review-skip.md`만 인정(bare `reviews/` 제거). R-1 implement 창에서 FID-wide exec-evidence fallthrough 제거 → receipt 필수.
- **enrich 스캔 LC_ALL=C 가-힣 collation false-FAIL** — locale 고정 환경에서 한글 클래스 오류로 placeholder 스캔이 깨지던 문제 수정.
- **validate-structure evaluator 마킹 기대 6→7** — `design-reviewer-ko` 추가로 T15.a 기대값 정합.

### Removed
- **죽은 파일·디렉토리 30건 제거 (Tier 1)** — `examples/` 24 파일(실행 러너 0곳·바이트 동일 복제·상시 FAIL 방치) · `scripts/tests/v0.4-pre/`·`v0.4a/` · `screens/main.{md,html}`. 문서 dead-ref 정리. FID 20260728-dead-file-cleanup.

## [1.59.0] — 2026-07-24

### Fixed
- **false-block 9호 — run-verification whitelist subdir 러너 인식 (#238)** — `run-verification.sh` whitelist 가 monorepo 테스트 호출 `cd <subdir> && npx|pnpm|yarn exec <runner>` 형태를 미인식(→`PARTIAL`→실행-근거 게이트 불인정→커밋 deny)해, 외부 완주 1건이 `SPECOPS_GOVERNANCE_BYPASS` 를 9회(67% 동일 사유) 우회하던 실측 단일 병목을 봉합(감사 plugin-evaluation-20260723 처방 #1). `_WHITELIST_PAT` 에 선택적 `cd <상대subdir> &&` 접두 + `npx <bin>`·`pnpm|yarn exec <bin>` 러너형 편입(단일라인 단일따옴표 유지), exec 루프에 `( cd "$dir" && "${rest[@]}" )` 서브셸 직접-exec 분기(no-shell·부모 cwd 비오염·`ec=$?` 불변식 보존). 절대경로(`npx /abs`·`cd /abs`)·트래버설(`../`)·임의 `&&` 체인·옵션주입(`npx --yes`)·bare `pnpm vitest` 는 차단(bin 선두 문자 `[A-Za-z0-9_@]` 제한). 부가: subdir 명령이 PASS 되어 evidence `RUN-VERIFICATION-RESULT` PARTIAL→PASS → #236 implement-면제 경로 도달가능.
- **세션-env BYPASS 감사추적 + fail-open rc=2 문서화 (#239)** — `pretool-governance.sh` 의 세션-env `SPECOPS_GOVERNANCE_BYPASS` 우회가 friction-log **무기록**으로 allow 되던 감사 공백(상한 3호)을 봉합: `log_friction "BYPASS-ENV" 1 <snippet> 0` 기록 후 allow — **막지 않고 기록만**(공식 탈출구 유지, 5원칙 4 주권), `.specops` 관할 가드로 비-specops repo 월권 방지, `|| true` 로 allow 불변식 보존(`principle`·`offset` 은 `--argjson` 유효 JSON 필수 — 숫자). `CLAUDE.md` fail-open 열거에 `tool_use 이벤트 0건(rc=2)` 케이스 추가(`governance-lib.sh:142 return 2` 실코드 정합, 상한 2호). 테스트 자기오염(기존 T3 가 격리 없이 세션-env BYPASS 실행 → run-all 시 실제 감사로그 오염) 격리 + suite-wide 무오염 회귀 락(`T-no-selfcontam`, flip-test 로 비-vacuous 실증).

## [1.58.0] — 2026-07-23

### Changed
- **plan-reviewer 단일화 — general-purpose Plan Document Reviewer 흡수 (#237)** — planning-ko 가 같은 plan.md 를 두 서브에이전트(general-purpose Plan Document Reviewer + plan-reviewer-ko)로 이중 검증하던 구조를 전용 Evaluator 로 단일화. 두 리뷰어는 순수 중복이 아니라 spec준수(Completeness·Spec Alignment) ↔ eng품질(TDD·타입·경계) 상보 관계였으므로, plan-reviewer-ko 를 4관점 → **6관점**(스펙 커버리지·스펙 정합 흡수)으로 확장하고 spec.md 도 읽도록 검증절차를 수정한 뒤 general dispatch 를 제거했다 — plan 단계 dispatch 1회↓ + **커버리지 무손실**. `plan-document-reviewer-prompt.md` 는 `run-plan-ab.sh` LLM A/B eval 픽스처로 유지(lifecycle 경로만 분리).

### Removed
- **규범문서 미구현 스캐폴딩 2건 제거 (#237)** — `file-based-communication-ko` 의 페이로드 로깅 절(`log-subagent-calls.sh` — 미구현 dangling)과 `structured-artifacts-ko` 의 session-start handoff 요약 주입 "구현 예정" 줄을 제거. 규범 문서에서 미완 로드맵 항목을 정리(session-start.sh 미구현 실측 확인 후).

## [1.57.0] — 2026-07-23

### Fixed
- **R-1 거버넌스가 implement 단계 커밋을 구조적으로 차단하던 문제 (FID 20260723-lifecycle-robustness)** — implement 단계의 태스크별 TDD 커밋은 R-1 면제 조건 ②(`/verify PASS` 앵커 · evidence stamp)를 **구조적으로 충족할 수 없다** — `/verify` 는 후속 단계라 커밋 시점엔 앵커가 존재하지 않는다. 그래서 정직한 흐름도 매 커밋 `SPECOPS_GOVERNANCE_BYPASS` 로 몰렸다(20260722 screen-design FID 실측 5+회 — BYPASS 관성의 시작점). `hooks/governance-lib.sh` `apply_lookback_rule` 에 R-1 한정 면제 경로 신설: transcript 에 러너 `VERIFY: PASS` **실행증거**(`_exec_rc=0`, 엄격 — fail-open `rc=2` 불인정)가 있고 FID 가 implement 창(`tasks.md` 존재 ∧ `evidence.md` 부재)에 있으면 커밋을 면제한다.
  - **자기보고 아닌 실행증거 기반** — 위조 불가. `_verify_exec_evidence` 의 `lasthit > lastedit`(마지막 편집 이후 실행 요구)가 "run-all 통과 후 임의 코드 편집→커밋" 우회를 봉쇄한다(편집 시 `exec_rc=1` 로 무효화).
  - **evidence.md 생기는 즉시 경로 닫힘** — post-verify 는 기존 앵커로 판정. R-2(PR)는 verify 이후라 미대상.
  - 회귀 테스트 3건: T6.B1(면제) · T6.B2(실행증거 없으면 deny — 위조방지) · T6.B3(evidence.md 존재 시 닫힘).
- **emit-context 소프트 실패가 exit 0 으로 통과하던 문제 (FID 20260723-lifecycle-robustness)** — `scripts/dag/emit-context.sh` 의 `ac_summary()` 가 AC 요약 텍스트 추출에 실패해도 WARN 만 내고 빈 요약으로 `EMIT: N files` exit 0 통과했다(20260722 실측: `## AC-N` h2 헤더가 추출 패턴 밖 → 빈 요약 17건, 무인 모드면 빈 컨텍스트로 dispatch). ① `ac_summary` 패턴을 `###` → `#{2,3}` 로 넓혀 `##`(h2) 헤더도 추출(#209 bullet 겸용 완화 철학 연장). ② 그래도 추출 실패(AC-id 토큰은 존재하나 헤더/불릿 전무 = 진짜 drift)면 write **전** 원자적 `exit 1`(부분 잔류 0) — 빈 AC dispatch 차단. 회귀 테스트 2건(h2 구제 · fail-closed).

## [1.56.0] — 2026-07-23

### Added
- **화면설계 껍데기 방지 — 마커 계약 + 판정 헬퍼 (#235, FID 20260722-screen-design-quality)** — `/start-all` batch 경로에서 화면설계서가 템플릿 껍데기로 남던 문제를 기계적 판정으로 종결. `#203`·`#204` 가 산문 지시로 대응했다 2회 재발한 실패 클래스를 마커 1줄로 이진 판정한다.
  - **마커 단일 출처** — `templates/screen.md`·`screen.html` 에 공유 마커 주석 1줄, `scripts/_internal/design-screen.sh` 에 `SCREEN_PLACEHOLDER_MARKER` 상수 + `screen_is_placeholder()` 함수 + `--check` CLI 진입점. 판정은 템플릿 **본문 리터럴이 아니라 마커에만** 의존해 본문 drift 에 면역이다(뮤테이션 쌍 테스트로 리터럴 grep 회귀 상시 차단).
  - **템플릿 상세화** — `templates/screen.md` 필수 코어 5→8섹션(필드 정의표·데이터 소스·에러 메시지 신설) + 조건부 4섹션(RBAC·반응형·접근성·진입/이탈, 미해당 시 섹션 자체 생략 — `—` 채우기 금지로 batch 토큰 선형 유지). 데이터 소스는 `api-spec.md`·`data-model.md`(Step 5.6) 참조로 연계.
  - 신규 bash 회귀 4스위트 47단언 + `run-all` baseline 99→103.

### Changed
- **화면 생성 3경로 껍데기 판정 대칭화 (#235)** — `commands/start-all.md` Phase 2.5 · `skills/specifying-ko/SKILL.md` Step 5.5 의 재사용 판정을 "경로 존재" → "마커 부재"로 교정하고, `.md` 필수 8섹션 완성 요건을 `design-screen(s).md` 와 대칭화(lifecycle 안/밖 비대칭 해소). `skills/verifying-evidence-ko/SKILL.md` 역방향 net 에 화면 껍데기 backstop(비차단 경고 + 차기 버전 승급 조건) 추가.

### Fixed
- **Phase 2.5 부재 파일 오판 + 혼합 상태 데이터 손실 (#235, 외부 critic 3중 수렴)** — `start-all.md` 재사용 판정이 무조건 적용돼, 실파일 없는 화면이 `--check` exit 1(FILLED)로 "재사용, 재생성 안 함"으로 오판돼 **영영 생성 안 되던** 침묵 버그. `specifying-ko` 와 동일한 "파일이 없으면 생성" 존재 가드를 미러링. 아울러 껍데기 짝 덮어쓰기 시 `PLACEHOLDER:` 로 지목된 파일만 선별 덮어쓰고 이미 채워진 짝은 보존(혼합 상태 손실 방지).

## [1.55.0] — 2026-07-22

### Changed
- **플러그인명 `specops-auto-ko` → `specops-ko` (BREAKING)** — 플러그인 식별자·skill 네임스페이스·로컬 마켓플레이스명이 모두 바뀐다. Skill 호출은 `specops-auto-ko:<name>` → `specops-ko:<name>`, 마켓플레이스 키는 `specops-auto-ko-local` → `specops-ko-local`, 활성화 키는 `specops-ko@specops-ko-local`. 사용자는 `~/.claude/settings.json` 의 `enabledPlugins`·`extraKnownMarketplaces` 키를 갱신하고 Claude Code 를 재시작해야 한다.
  - 메타 skill 디렉토리 `skills/using-specops-auto-ko-ko/` → `skills/using-specops-ko/` (기계적 치환 시 발생하는 `-ko` 중복 제거).
  - 거버넌스 규칙(`hooks/rules.jsonl`)의 `negative_skill_pattern`·`trigger_skill_pattern` 도 새 네임스페이스로 갱신 — 구 네임스페이스로 호출된 skill 은 verify 크레딧을 받지 못한다.
  - `validate-structure.sh` `XREF_ALLOW` 에 구 플러그인명(`specops-auto-ko`)을 케이스 스터디 파일명 참조용으로 유지.
  - GitHub 저장소도 `andyko18/specops-ko` 로 rename (구 URL 은 GitHub 리다이렉트).

## [1.54.0] — 2026-07-21

### Fixed
- **리뷰 감사 역방향 대조 — 리포트를 아예 안 남긴 경우 봉합 (dogfood 20260721 HIGH-4)** — 기존 `check-review-audit.sh` 는 `reviews/ → dispatch-log` **한 방향**만 봤다. 그래서 리뷰 판정을 **파일로 아예 안 남기면** `reviews/ 부재 = SKIP` 으로 통째로 비껴갔다 — Generator↔Evaluator 분리가 조용히 0 이 되는데 `VERIFY: PASS` 는 그대로 났다. 실물(전수 스캔 적발): `.specops/20260713-llm-eval-nrun/dispatch-log.md` 가 `reviews/all-B-report.md`·`all-C-report.md` 를 기록해 놓고 **그 파일이 없다** — 판정을 대화로만 흘린 것이다. dispatch-log 가 참조하는 `reviews/*.md` 의 실재를 대조하는 역방향 검사를 추가했다.
  - **판별자 = dispatch-log 존재** (false-block 회피). "tasks.md 있는데 reviews/ 없으면 FAIL" 은 **기각**했다 — 실측상 그 조건에 걸리는 기존 FID 가 16건 중 5건(31%)이고, 그중 4건은 e2e fixture·플러그인 self-maintenance 처럼 dispatch 루프를 돌지 않는 정당한 직접 작업이다(이 PR 을 만든 FID 자신도 포함). dispatch-log 가 있다 = 루프를 돌았다 = 판정 산출물이 있어야 한다. 로그 부재는 SKIP.
  - **템플릿 placeholder 제외** — dispatch-log 템플릿의 꺾쇠 자리표시자(`reviews/<task-id>-B-feedback.md`)를 실재 요구하면 템플릿을 복사한 모든 FID 가 즉시 FAIL 한다.
  - 전수 검증: 기존 FID 전체에 돌려 **새로 FAIL 나는 것은 2건뿐이고 둘 다 진짜 누락**이다(`20260713-llm-eval-nrun`·`20260709-tpl-session-progress-design`). false-block 0건.
- **batch PR 뭉개짐 teeth 를 산문에서 훅으로 이동 (dogfood 20260721 test1)** — `/start-all-auto` 실전 감사에서, 무인 batch 가 7개 per-FR FID 를 BATCH_ID 하나(`.specops/batch-20260721/`)로 뭉갠 채 PR 을 냈다. 뭉개짐을 막는 `batch-state.sh` 하드 스캔은 `commands/start-all.md:114` **산문 지시**에만 있었고 R-2 훅은 verify 만 보므로, 아무도 호출하지 않은 채 통과했다(실측 재현: 사후에 돌리니 `MISMATCH` — 돌렸다면 PR 전 차단됐다). `hooks/pretool-governance.sh` 가 `gh pr create` 시 최신 `.specops/batch-*/queue.md` 에 신규 `batch-state.sh --gate` 를 자동 실행한다.
  - **`--gate` 는 기본 모드와 판정 기준이 다르다** — 뭉개짐 신호(per-FR 산출물 3종 부재·진행기록 `/verify PASS` 줄 부재·라벨 오염)만 차단하고, 드리프트·미완·중복은 차단하지 않는다. 후자는 batch 운영 판단이고(M1 batch → M2·M3 batch 분할은 정당), 그것으로 PR 을 막으면 정당한 부분 batch 를 차단하는 **false-block 재생산**이 된다.
  - **라벨 화이트리스트 동반이 필수였다** — 산출물·진행기록 teeth 는 `IMPL_DONE` 행만 수집하므로(`batch-state.sh:87`), test1 처럼 `DONE` 으로 쓰면 **검사 대상 0건 → 조용히 통과**한다. 라벨 검증 없이 teeth 만 훅에 붙였다면 실물 케이스를 여전히 못 잡았다. 미인식 라벨은 차단 사유로 승격(gate 모드 한정 — 기본 모드 판정 불변).
  - **인라인 BYPASS 불인정** — batch PR 은 비가역이라 security Critical/High 와 동급으로 다룬다(`start-all-auto.md:56` 선례). 없으면 test1 이 한 그대로 사유 한 줄로 우회된다. 세션 env BYPASS(사용자 주권, 5원칙 4)는 보존. 중간 커밋은 대상 아님(chain 상 verify 앞이 정상).
  - **판정 범위 = 진행 중(ACTIVE 마커) batch 한정** — 첫 구현은 `ls -t .specops/batch-*/queue.md | head -1` 로 최신 batch 를 집었는데, 이것이 **새 false-block(6호)을 만들었다**. `.specops/*` 는 gitignore 라 뭉개진 batch 디렉토리가 디스크에 무기한 남고, 그 batch 와 **무관한** 단일 FID 작업의 PR 이 과거 라벨 오염으로 차단된다(실측 재현: specops-test1 의 무관한 PR 이 `batch-20260721b` 의 `DONE` 때문에 deny). 게다가 이 게이트는 인라인 BYPASS 앞이라 탈출구가 "세션 전체 거버넌스 해제"뿐이 된다 — false-block 의 유일한 출구가 보호 장치 무력화라는 최악의 형태다. `start-all` Phase 0 이 `.specops/$BATCH_ID/ACTIVE` 를 남기고 Step D 가 PR 성공 후 지우며, 게이트는 마커 있는 batch 만 판정한다. **한계(5원칙 5)**: 마커는 오케스트레이터가 쓰는 것이라 안 만들면 게이트도 안 열린다 — 그럼에도 이 설계를 택한 건 놓치는 비용(기존 상태 복귀) < 오차단 비용(완주율 킬러)이기 때문이다.
  - **판정 조건 = 마커 ∧ 브랜치 일치** — 마커만으로는 부족하다. 마커는 "batch 가 진행 중인가"에 답할 뿐, 게이트가 필요한 답은 "**이 PR 이 그 batch 의 PR 인가**"다. 특히 **중단된 batch** 가 치명적이다: 마커는 PR 성공(Step D)에서만 지워지는데 이 게이트의 목적이 뭉개진 batch 를 막는 것이라, 막힌 batch 는 Step D 에 도달하지 못하고 마커가 영구히 남아 이후 **모든** 무관한 PR 을 차단한다 — 게이트가 잘 막을수록 오염 마커가 쌓이는 역설. 판별자는 브랜치다(batch PR 은 `feat/<BATCH_ID>` 에서 난다 — `start-all.md` Phase 0). 불일치·판정 불가는 skip 하여 false-block 회피 방향으로 오류를 낸다. 브랜치 조회는 `symbolic-ref`(unborn HEAD 에서도 동작) — `rev-parse` 는 첫 커밋 전 batch 에서 실패해 게이트가 가장 필요한 시점에 침묵한다.
- **R-1/R-2 deny 메시지가 실제 면제 조건과 불일치 (false-block 5호)** — 면제는 **두 겹**이다: ① transcript 의 러너 실행 증거(필요조건) ② FID-scoped 앵커(session-progress `/verify PASS` 줄·evidence 스탬프·Skill 호출). 구 문안은 ①만 안내해, 지시대로 러너를 재실행하고도 ②가 없어 또 막힌 모델을 BYPASS 로 몰았다. test1 transcript 실측: `#418` deny(정당 — verify 후 코드 수정으로 stale) → `#419` 안내대로 러너 재실행 `VERIFY: PASS` → `#420` **동일 메시지로 재차단** → `#421` BYPASS. `detect_fid` 가 빈값(session-progress 에 `## <FID>` 섹션 부재)이면 그 사실을 진단으로 표시하도록 메시지 분기 추가.
  - **기각한 오답**: 최초 진단은 "`session-progress-append.sh` 정규식이 `batch-` FID 를 거부하는 것이 결함"이었다. 틀렸다 — `batch-YYYYMMDD` 는 BATCH_ID(브랜치·큐 디렉토리)이고 verify·append·detect_fid 에 넘어가야 할 것은 per-FR FID 다(`start-all.md:93,103,107,122`). 정규식은 옳게 동작했고, 수용하도록 고쳤다면 뭉개짐을 제도화하는 역행이었다.

### Added
- **입력 프로브(fixture-외) 의무 — Phase C 리뷰어 (test1·test2 델타 감사 F4)** — 리뷰어 3종 어디에도 "fixture 밖 입력을 직접 만들어 던지는" 의무가 없었다(실측: `agents/*-reviewer-ko.md` 에 프로브·스트레스 문구 0건). 있는 건 `code-reviewer-ko` 의 "**작성자 테스트가** 경계값을 커버했나" 수동 점검뿐이라, 작성자가 상상하지 못한 입력 클래스는 내부 리뷰를 통과한다. 실측 대가(test2): 블록주석 마스킹 봉합이 내부 Phase C 통과 후 **외부 리뷰의 fixture-외 스트레스 프로브에 4라운드 연속 Critical**(문자열 오열림·라인주석 누출·text block phantom)을 맞고 8커밋을 썼다. `code-reviewer-ko` 프로세스에 4단계 신설: 변경이 입력을 파싱·검증·변환·매칭하면 **fixture 미커버 입력 클래스 최소 1종을 지목·합성·실행**하고 **명령과 출력을 원문 인용**(요약 주장은 프로브 불인정), **fixture·expected 파일 수정 금지**(판정 근거 오염), 표면 없으면 `해당 없음 + 사유`(침묵 skip 금지). 보고서 `## 입력 프로브` 섹션 추가. `test-gate-presence` 3-패턴 회귀(프로세스 단계·fixture 수정 금지·보고서 섹션 — 각각 다른 소실을 잡도록 mutation 3/3 검증).
  - **등급 한계(5원칙 5)**: **guidance-level** 이다(#226 P4 넛지와 동급). 프로브는 행동이라 파일 대조로 검증 가능한 객관 신호가 없어, 회귀 테스트는 **문구 존재**만 본다 — 실제 프로브 수행 여부는 검증하지 않는다. 같은 PR 계열의 F1(누락 검사)이 teeth 인 것과 지점이 다르며, 그 천장을 알고 넣는다.
- **적용 범위**: `code-reviewer-ko`(Phase C) 한정. `spec-reviewer-ko` 는 스펙 준수 판정, `plan-reviewer-ko` 는 실행 전 설계 단계라 프로브 표면이 없다 — 근거가 있는 곳에만 배선(과잉 전파 금지).
- **리뷰 감사 추적 기계 검사 — Evaluator 규칙에 teeth (test1·test2 델타 감사 F1)** — `#224`(v1.51.0)가 "부모 self-review 금지 / 모델 override 재dispatch / dispatch-log degradation 기록"을 명문화했으나, teeth 는 `test-gate-presence`(스킬 본문 섹션 존재 mutation)뿐이라 **산출물이 그 규칙을 지켰는지 검사하는 층이 0** 이었다. 실측: test1 `20260717-approval-rbac` 이 `reviews/T10-B-report.md` 만 남기고 `dispatch-log.md` 에 T10 행을 누락 → 아무 게이트도 반응 없음. 신규 `scripts/_internal/check-review-audit.sh` 가 `reviews/<task-id>-[BC]-{report,feedback}.md` ↔ dispatch-log 행을 경계매칭(T1 이 T10 을 덮지 않음)으로 대조하고, `run-verification.sh` 가 이를 호출해 미기록 시 `VERIFY: PASS` 를 거부 — 실행-근거 게이트(R-1/R-2)와 직결이라 커밋도 열리지 않는다. 테스트 명령 0건 FID 도 감사 대상(`NO COMMANDS` 우회 구멍 봉합). 산출물 부재는 SKIP(fail-open)이라 무관 repo·초기 FID 월권 0. `implementing-ko`·`verifying-evidence-ko` 본문 배선. 신규 테스트 11건(T1.a~T3.c, RED 10 → GREEN 11).
  - **스코프 한계(5원칙 5)**: **누락 전용**이다. dispatch-log 행이 존재하되 내용이 거짓인 falsification(부모 인라인 판정을 서브에이전트로 기재)은 자기보고라 파일 대조로 판별 불가 — transcript join 은 `context-resets-ko` 의 implement↔verify 리셋 경계 때문에 대부분 fail-open 이라 실효가 낮다(#120 자기보고 구조적 한계 동일 클래스).

## [1.53.0] — 2026-07-19

### Fixed
- **전수 감사 구체 버그 4건** (커맨드·스킬·에이전트 58 유닛 평가 산출):
  - **skip-tracker.sh security 게이트 死문** — `skip-tracker.sh` 는 헤더 `^## /${gate}-test` 하드코딩이라 security(헤더 `## /security-review`)를 못 잡아, `security-review-ko` 의 SKIP 관측 지시가 死문이었다. 게이트→헤더 매핑(`skip::header`) 추가로 integration/performance/security 3게이트 정합(하위호환 유지). 신규 테스트 T17~T20 + mutation 검증.
  - **`dispatching-parallel-agents-ko` used_by 허위 역참조** — `systematic-debugging-ko` 를 호출자로 주장하나 실측 grep=0 → 제거.
  - **`using-git-worktrees-ko` `~` 따옴표 내 미확장** — `path="~/.config/..."` 는 리터럴 `~` 디렉토리 생성 → `"$HOME/.config/..."` 수정.
  - **`finishing-a-development-branch-ko` used_by 과소기재** — 실제 호출자 `performance-test-ko`·`e2e-test-ko` 추가.

## [1.52.0] — 2026-07-19

### Added
- **유지보수 오분류 백스톱 (specifying-ko [신규 분기])** — 커맨드 감사 20260719 [MED]: entry 라벨(`<!-- entry: maintain -->`)은 모델-prepend 프로즈라 훅 강제가 없어, 메타스킬 유지보수 분류·라벨이 누락되면 유지보수 요청이 [신규 분기]로 새어 analyzing-ko HARD GATE(current-state·impact-analysis)를 통째 skip → 회귀 AC-R 미적용. specifying-ko [신규 분기] 진입점에 soft 백스톱 추가: 요청이 **기존 코드·동작 수정**이면 신규 진행 전 1회 확인(유지보수 전환 시 analyzing-ko 선행). 하드강제 아님(5원칙4 주권)·오탐 방지(신규 창작이 "개선/변경" 어휘 포함은 흔하므로 기존 산출물 실제 수정 시에만 확인). 관찰 실패 0의 백스톱 — 아키텍처상 라벨은 프로즈라 완전 기계강제는 불가.
- **재개 desync 자동표면화 (SessionStart)** — 완주율 레버: 정체 후 재개 시 session-progress breadcrumb 이 git·dispatch 보다 뒤처져 재개 모델이 "미구현" 오판·방치(dogfood test1 FR-3, 24h 정체). `/status` reconcile(#220)은 탐지하나 수동 실행 필요였다. SessionStart 훅이 진행 중 FID 에 `reconcile-check.sh --hook` 을 자동 실행 → 증거 frontier > 기록 frontier 일 때만 DESYNC 경고+재개점을 `<session-progress-reconcile>` 로 주입(정합 시 무출력, 노이즈 0). session-progress 자동 덮어쓰기는 하지 않음(표면화만 — breadcrumb 오염 방지). frontier 사다리·reconcile 로직을 `scripts/_internal/reconcile-check.sh` 로 추출해 show-fid-status·SessionStart 단일 SoT(drift 방지). 신규 테스트 9건(reconcile-check 6 + session-start-reconcile 3), mutation 검증.

### Fixed
- **외부 신규진입 블로커 — 번들 스크립트 상대경로 → `${CLAUDE_PLUGIN_ROOT}` 정식형** (funnel dogfood 적발): 26개 커맨드/스킬 본문이 `bash scripts/...` **상대경로**로 번들 스크립트를 호출해, 사용자 프로젝트 cwd(≠plugin)에서 `No such file or directory` 로 lifecycle 전 단계가 깨졌다. 모든 dogfood/e2e 가 plugin repo 내부(cwd=plugin)서 돌아 상대경로가 우연 해소돼 여태 미적발(자기repo 편향). 공식 docs 확인: Skill·agent 본문의 `${CLAUDE_PLUGIN_ROOT}` 는 로드 시점 절대경로 치환 → 정식형 `bash "${CLAUDE_PLUGIN_ROOT}"/scripts/...` 로 전면 전환. 예외: 자기유지보수 전용(release·e2e-test-ko, cwd=plugin) + 라이브 호출 아닌 산문·PR템플릿.

### Added
- **`validate-structure.sh` `plugin_root_paths` 회귀 검사**: 사용자 프로젝트서 실행되는 커맨드/스킬 본문에 상대 `bash scripts/` 재발 시 FAIL (예외 allowlist 반영). red-green 검증.

## [1.51.0] — 2026-07-18

### Added
- **공유 유틸 창발 중복 경고 (P2) + implement 전환 선언 넛지 (P4) — test2 회고** — **P2**: foundation-manifest 는 사전 선언된 공통부 재사용만 게이트하지, 형제 FID 가 각자 만드는 유틸의 **창발 중복**은 못 잡는다(전방 계약≠후방 탐지). test2 실측: `mask_block_comments`·`PRUNE`/`ANALYZE_EXT` 가 4~5 FID 복제 → "sysprobe-lib 승격" backlog 반복. planning-ko 에 판별 가이드(재사용 유틸 → 공통 lib 배치·manifest 등재 후보, 애매 시 `공유후보:` 1줄+advisor) 추가 — 하드게이트 아님. **P4**: R-3 warn 12건이 전부 `implementing-ko`(자동 체인이 선언 없이 직접 호출). decomposing-ko 의 implement 전환에 "호출 직전 한 줄 선언" 넛지 추가(근본=전환 지점). teeth: test-gate-presence(mutation 2/2). ※ P4 는 guidance-level(자동 체인이라 완전 제거는 미보장)이고 R-3 은 audit-only 라 잔여 warn 은 benign.

- **detection-proof — 테스트 전용 태스크의 RED 대체 (P5, test2 정주행 회고)** — RED-first 는 새 동작 구현을 가정하는데, **이미 정상 동작하는 로직에 테스트를 추가**하는 태스크(커버리지·스캐너 탐지 테스트·회귀 락인)는 자연 RED 가 없다. tdd-ko 의 "테스트가 통과? → 테스트 수정"은 이 경우 오처방(테스트가 옳다). `tdd-ko` 에 detection-proof 성문화: **변이(규칙 뒤집기·유령 주입)로 테스트가 FAIL 하는지 확인**해 탐지력 증명 — "변이해도 통과=tautology=RED 미충족". RED 의 본질은 "실패 테스트를 먼저"가 아니라 "**fail 할 수 있음을 관찰**"이라는 원칙 명문화(변이본 FAIL 원문 인용 = RED 인용 규약 대칭). test2 run 이 스스로 발명한 패턴을 성문화 — decomposing-ko 는 tdd-ko 준수라 자동 전파. teeth: test-gate-presence(섹션 삭제 mutation).

### Fixed
- **Evaluator fable 하드고정이 크레딧 소진 시 Generator↔Evaluator 붕괴 (P1 — test2 정주행 회고)** — `plan-reviewer-ko`·`spec-reviewer-ko`·`code-reviewer-ko` 가 `model: fable` 고정이라, fable 크레딧 소진 시 **3 Evaluator 전부 dispatch 불가** → 부모(생성자) self-review 로 후퇴 = **Evaluator=Generator 편향**(specops 핵심 가치인 독립 리뷰 붕괴). test2 완결 run 의 실측 근거: 부모 self-review 가 놓친 Critical(I-1 self-gate exit 마스킹)을 **독립 비-fable 리뷰어가 잡았다**(독립-약한 모델 ≫ 편향-강한 모델). fix: fable 불가 시 **같은 Evaluator 를 독립 서브에이전트로 가용 모델 override 재dispatch**(컨텍스트 분리로 불변식 보존), **부모 self-review 후퇴 명시 금지**, dispatch-log degradation 기록 + 고위험 FID 크레딧 복구 후 재리뷰 권고. fable 고정(강한 리뷰어 보장)은 가용 시 유지 — graceful floor. implementing-ko(B/C) + planning-ko(plan-reviewer) 배선. teeth: test-gate-presence(mutation 2/2, cross-ref 오매칭 조임 포함).


### Changed
- **E2 최종 리뷰 right-size — 단일 태스크 중복 제거 (경제성)** — `implementing-ko` 의 wave-loop 후 "최종 코드 리뷰어(전체 구현)"는 태스크 간 통합을 보는 단계인데, **태스크가 1개**면 "전체 구현"="그 1 태스크"라 이미 Phase C 가 리뷰한 것과 **literal 중복**이었다. 태스크 수==1 일 때만 최종 리뷰 skip(기계적 게이트, 품질 손실 0 — 동일 산출물의 두 번째 리뷰 제거). **멀티태스크 Phase B/C 는 무변경** — 그 리뷰가 실 Critical(RBAC 권한상승 등)을 잡는 품질의 원천이라 명시적 축소 금지 가드 추가. dispatch-log 투명성 기록(F-12 규약). teeth: test-gate-presence(mutation 3/3). ※ 경제성의 대부분은 이런 코드 레버가 아니라 "자기수리 나선 중단"(행동)에 있음 — 본 변경은 안전한 중복 제거 한 건으로 한정.

### Fixed
- **`/status` reconcile — 유지보수 흐름 `/analyze` 단계 누락 (#220 자기결함)** — reconcile 단계 사다리가 `specify` 부터 시작해 유지보수 진입 단계 `/analyze` 를 몰랐다. `/analyze 완료` 가 기록돼도 recorded=0 오라벨 + current-state.md·impact-analysis.md 가 증거 사다리에 부재 → 모든 유지보수 FID 를 오판(cry-wolf 리스크). dogfood 로 test2 `scanner-blockcomment-fix`(유지보수 FID) 를 실제 조회하다 발견 — "shipped 도구를 실사용 중 나온 자기결함" 이라는 개선 명분 기준의 실례. 사다리에 `analyze`(rank 5, specify 앞) + analyze 산출물 증거 추가, 비균일 간격 위해 `_stage_next` 명시 매핑. teeth: test-show-fid-status T9(정합)·T10(analyze→specify desync). ★ T9/T10 초안이 상단 이력 echo 의 `analyze` 로 tautology-PASS → reconcile 섹션 스코프로 정정(grep 앵커 교훈 자체적용).

### Added
- **FID 크기 규약 — per-FID 태스크 수 완성율 소프트 신호 (`decomposing-ko`)** — per-태스크 크기(2~5분)는 있었으나 **per-FID 크기(총 태스크 수)** 가이드가 전무했다. dogfood 실측: test2 3-태스크 FID **6/6 완주** vs test1 10-태스크 FID **24h+ 정체**(태스크 각각은 정상, FID 전체가 7.5h 마라톤 → 세션 경계 이탈). 권장 스코프 ≤6 태스크, 7+ 이면 `⚠️ FID-SIZE` 소프트 신호 + 예방(다음 FID 는 수직 슬라이스로 작게)·완화(태스크별 checkpoint→`/status` reconcile 재개) 택1. 하드 게이트 아님(리스크 인지용). teeth: test-gate-presence(silent drift 방어). #220 reconcile(정체 복구)의 짝 — 이건 정체 예방.
- **`/status` reconcile — 기록↔증거 frontier 대조로 정체 재개점 제시** — session-progress 단독은 정체 후 현실을 **과소보고**한다(dogfood test1 FR-3 실측: `/tasks` 기록 상태에서 12커밋+dispatch T7까지 존재했으나 주 breadcrumb 만 읽어 "구현 안 됨"으로 오판 → **24h+ 방치, 실제 잔여 작업은 5분**. 완성율 킬러의 실물). `show-fid-status.sh` 가 **기록 frontier(session-progress 최고 단계) ↔ 증거 frontier(spec/plan/tasks·dispatch-log DONE·feat/<FID> 브랜치 커밋·evidence.md·reviews/)**를 8단계 rank 로 대조 — 증거가 앞서면 `⚠️ DESYNC` + **진짜 재개점**(증거+1 단계) + **기록 보정 구간**(recorded+1~evidence) 제시. 정합 시 경고 0(오탐 방지). 실 FR-3 정체 상태 재현 검증: "재개점 review 부터, implement~verify 기록 보정" 정확 산출. teeth: test-show-fid-status T6~T8.

## [1.50.0] — 2026-07-18

### Fixed
- **posttool R-1/R-2 감사 침묵 봉합 — 감사 스코프를 "방금 액션의 범위"로** — posttool 이 working-tree 기준 `is_docs_only_change` 를 쓰는데, 커밋 직후 잔여 dirty 는 거의 항상 tracked `.specops/session-progress.md` 뿐이라 `.specops/*` 면제(#214)에 걸려 **감사가 통째로 skip** — #214 이후 R-1 posttool warn 이 전 repo 0건이던 실물 원인(pretool block 만 남는 절반 가시성. 기존 T8.a 는 git repo 부재 fixture 라 빈 diff fail-safe 로 위장 통과). 신설 `is_docs_only_audit_scope`: R-1 = `HEAD~1..HEAD`(방금 커밋), R-2 = `base...HEAD`(PR 범위) — whitelist 는 `_files_all_docs` 로 공유(drift 방지). pretool(액션 前 = working-tree 가 곧 커밋 범위)은 무변경. range 실패(최초 커밋·base 미검출)는 비면제 fail-safe(감사는 기록이라 과잉 방향이 안전). teeth: test-hooks T8.e/f·test-lib T-scope.a~d.
- **실행증거 신선도 게이트 — 세션 전역 만능 면제표 봉합** — `_verify_exec_evidence` 가 윈도우·FID 스코프 없이 transcript 전체를 스캔해, 세션 초반 **다른 FID 의** `VERIFY: PASS` 1회가 세션 끝까지 모든 커밋을 여는 만능 면제표였다(dogfood test1 실측: FR-2 verify 가 FR-3 미검증 implement 커밋 8+개를 전부 면제 → friction 무흔적. 계측 probe 로 서브에이전트 훅도 main transcript 로 평가됨을 확정 — "서브에이전트 게이트 갭" 가설은 기각, 실물은 staleness). 규칙: **마지막 실행증거 이후 비-`.specops` Edit/Write/NotebookEdit 가 있으면 stale**(수정→재검증 후 커밋이 정직 순서 — `_verify_passed_in_progress` vts>cts 와 동형). `.specops/` 아티팩트 Write(evidence.md 마무리)는 제외. 한계: Bash 경유 파일수정(sed -i)은 미탐(F-1 동류 heuristic). teeth: test-exec-evidence T-fresh.a~d.
- **인용 문자열 프로즈 false-block — `_strip_quoted_strings`** — printf/echo 인용 인자 속 프로즈("배포 후 (git commit 으로 기록)"·"build | git commit")의 `(`·`|` 선행자가 R-1/R-2 트리거와 오매칭돼 정직한 문서·코드 텍스트 작성이 차단됐다(dogfood 20260717 test2 모델 backlog "R-1 블록주석 내부 오검출" — probe 로 실재 확정. heredoc 경로는 기처리, 인라인 인용 인자가 잔여 표면). 인용 본문을 트리거 검사 입력에서 제거하되 **차단 우세 불변식** 유지: 더블쿼트 내 `$( )`·백틱은 실제 실행되므로 보존(deny 보존), 백슬래시는 bash 인용 의미대로 처리(blanket-bail 은 `printf "%s\n"` 주 형태를 전부 죽여 fix 무력화), `$'…'`·미종결 인용·awk 실패는 원본 후퇴. pretool prefilter + `apply_lookback_rule`(posttool 대칭) 양쪽 배선. teeth: test-pretool T-qs.1~6·4b.
- **커밋 메시지 BYPASS 표식 오염 가드** — 우회 커밋 메시지를 `BYPASS fix: …` 로 시작하는 오염(dogfood test2 `61f9e0d` — conventional commit 훼손, 릴리즈 노트·검색 오염)이 실측됨. bypass 경로에서 `-m "BYPASS…"` 를 deny + 정상 메시지 재작성 안내(우회 기록은 `SPECOPS_BYPASS_REASON`+friction-log 담당). teeth: test-pretool T-mp.a~c.

## [1.49.0] — 2026-07-17

### Added
- **batch 진행기록 teeth — batch-state check 5** (#214) — `/start-all` dogfood(specops-test1 재주행)에서 batch 가 skill 미호출 인라인 진행으로 session-progress 0줄 → R-1/R-2 면제 신호(`_verify_passed_in_progress`) 부재 → 게이트 차단 → 무사유 BYPASS 관성(커밋 3회+PR)이 실측됨. IMPL_DONE FID 마다 session-progress FID 섹션의 `- YYYY-MM-DD HH:MM /verify PASS` 줄(행 선두 앵커)을 batch PR 직전 하드 재검 — 부재 시 `[진행기록 누락]` + exit 1. start-all.md Phase 3 배선(재검 3종→4항목) + 안티패턴 2건(인라인 뭉개기·무사유 BYPASS 정면 돌파) 신설. teeth: test-batch-state T2.f/g.
- **인라인 BYPASS 사유 강제 — `SPECOPS_BYPASS_REASON`** (#214) — `SPECOPS_GOVERNANCE_BYPASS=1` 인라인 prefix 는 사유 병기 필수(무사유 deny + 형식 안내). 사유가 friction-log evidence_snippet 에 명령 원문째 남아 감사 가능한 우회가 된다. 세션 env 탈출구(사용자 주권)는 불변. teeth: test-pretool T36 계약 뒤집기 + T36b/c.
- **critic provider preflight·cascade — `_usable`** (#215) — specops-test2 정주행에서 claude 감지(`command -v` 통과) 후 실행 rc=127(stale shim/PATH 클래스) → 외부 critic 전 구간 실효 0 이 `FAIL (provider rc=127)` 로 위장됐다. `--version` preflight 로 실행 불가 provider 를 부재로 강등 → 다음 provider cascade(claude→codex→gemini→ollama) 또는 정직한 SKIP + stderr 진단. `CRITIC_BIN`(사용자 강제)은 계약상 preflight 제외. teeth: test-critic-ask T1.h/i.

### Fixed
- **design 산출물 커밋 false-block 5호** (#214) — Phase 2.5 design 커밋(`screens/*.html`)이 `.md` 한정 docs-only whitelist 에 걸려 차단 → BYPASS 남발 유인. `is_docs_only_change` 에 `screens/*.html`(루트 screens/ 한정 — `src/**/*.html` 은 비면제 유지)·`.specops/*`(아티팩트 도메인) 면제 추가. teeth: test-lib T-docs.n~q.
- **인용 공백값 prefix 트리거 우회 차단 + prefilter 동적 로드** (#214) — `FOO='a b' git commit` 처럼 인용 공백값이 VAR=val prefix 체인을 끊어 R-1/R-2 트리거를 통째로 비껴가던 기존 우회를 인용값 클래스 지원(deny-superset widening)으로 차단. 인용값 도입으로 pretool literal 에 quote-splice 가 생겨 T-H1(literal 복제 비교)이 구조적으로 깨짐 → prefilter 를 rules.jsonl `trigger_pattern` 동적 로드로 전환(T-R8 동형, drift 원천 제거). teeth: test-pretool T21b/T22b·test-rules T-H1/H1b.
- **정직한 BYPASS false-deny — 선행자 클래스 비대칭** (#215) — 사유까지 병기한 compound(`git add x && BYPASS=1 REASON=... git commit`)·함수 wrapper(`B() { ... }`) 우회가 `^줄시작` 앵커에 걸려 deny 되던 것(specops-test2 실측, 재시도 2회+ 낭비)을 트리거와 동일 선행자 클래스 `(^|[;&|({\`])` 로 정합. 메시지 내 토큰 언급(공백 선행)은 여전히 불인정(T37 보존). teeth: test-pretool T36d/e/f.

## [1.48.0] — 2026-07-16

### Added
- **`/init-project` Phase 0 기존 기획 문서 auto-discovery (3단 탐색)** — 실무는 PRD·기획서가 **이미 파일로 존재**하는 게 보통인데, 종전 감지는 `.specops/memory/brainstorming-*.md`(플러그인 자기 관습 파일명)뿐이라 repo 에 `prd.md` 를 두는 자연스러운 흐름이 안 먹혔다(온보딩 마찰 — 사용자 실지적). 3단 우선순위 신설: **0-a** args 명시 경로(`/init-project 쇼핑몰 docs/기획서.md`) → **0-b** 브레인스토밍 메모(기존) → **0-c** auto-discovery(`PRD*.md·prd*.md·기획*.md·요구사항*.md·requirements*.md` + `docs/` 변형 — 발견 시 **사용자 확인 필수**, 자동 소비 금지). 확보 문서로 PRD 6필드 초안 합성(없는 필드는 창작 금지·질문). Phase 11 근거 4원의 ① 을 "사전 문서"로 동기 확장. FR 표 보유 requirements 는 Phase 8a 보존 정책과 연계. teeth: `test-init-project` T23.a.

## [1.47.3] — 2026-07-16

### Fixed
- **advisor-ko 진단표 실측 정정** — `/advisor` 유효 옵션은 opus·sonnet·off 뿐(fable 미지원 실측). ∴ main=Fable 5 면 advisor 는 구조적 불가 — 진단표 안내를 "/advisor off + critic-ask 공식 대체 또는 main 하향 중 사용자 선택"으로 정정 (구 안내 "main 과 동급 이상 모델 재설정"은 Fable main 에서 실행 불가한 지시였음).
- **DB lifecycle 잔여 gap 3건 종결** (#152 보류분 — 코드 backlog 제로화): **gap3** 마이그레이션 테스트 정책 — `test-strategy.md` §4.5 신설(up→down→up 멱등·제약 위반 경로·인덱스 존재·expand-contract 데이터 보존, 도구 표 행 추가) + `tdd-ko` "마이그레이션(DDL)도 TDD"(멱등 테스트 먼저 RED). **gap5** verify 스키마 추출 heuristic 명세 — 도구별 위치(prisma/alembic/db/supabase migrations·ORM 스키마·raw DDL grep) + **ERD(mermaid) 수기 한계 고백**(자동 대조 기준은 §3 엔티티 표, ERD 는 권고만). **gap6** `data-model.md` PostgreSQL 편향 조건부화 — §1 에 비-PG 주의 노트(GIN→FULLTEXT/FTS5 치환·MongoDB document 모델 §3 대체·localStorage 축소 적용) + PK 생성 함수·at-rest 암호화 DB별 병기. teeth: `test-interface-routing-doc` AC-17~19.

## [1.47.2] — 2026-07-16

### Fixed
- **감사 P2/P3 + dogfood 관찰 2건 + 빈틈2 일괄 종결** (7건):
  - **R-4 러너 패턴 downstream 확장 (#209 전파)** — `test_runner_pattern` 의 `scripts/tests/` 하드코딩 2형(bash·`./` 직접)이 외부 repo 의 `bash tests/test-x.sh` 실행을 러너로 미인식 → 정직한 성공 주장이 R-4 false-warn. `(scripts/tests|tests?)/` 확장 + `test-rules` T9.f 회귀(RED→GREEN). verifying-evidence 러너 목록 prose 도 동기 정정.
  - **dogfood 관찰 A — trivial 스펙승인 중복 게이트 통합** — 설계승인+축약승인 직후 동일 내용 스펙의 3번째 승인 요구는 중복(4연속 게이트 실측). specifying-ko 에 [trivial 게이트 통합]: 내용 동일 시 1줄 고지 통과, 신규 논점·범위 변화 시 게이트 유지(주권 불변). teeth: `test-trivial-new-shortcut` AC-GATE-MERGE.
  - **dogfood 관찰 B — Phase B/C 판정 file-based 감사 추적** — PASS 가 부모 선언으로만 흘러 Phase C 가 B 통과 자격을 검증 불가(file-based-communication 위반, Phase C 리뷰어 실지적). implementing-ko 에 `reviews/<task-id>-B(-C)-report.md` 저장 + C dispatch 에 경로 포함 규약. teeth: AC-B-REPORT.
  - **TDD 감사 P2-① — plan-reviewer TDD 렌즈 오조준 정정** — "RED 스텝 누락=Critical" 은 tasks.md 기준인데 리뷰 대상 plan.md §5 는 설계상 카테고리만 담음 → 모든 정상 plan 이 Critical 나는 렌즈. "TDD 가능성"(§2 테스트 파일 계획·§5 테스트 가능 단위) 기준으로 재정의.
  - **TDD 감사 P2-② — 5스텝↔Red-Green-Refactor 명칭 관계 명문화** — tdd-ko 에 "5스텝=RGR 의 태스크 실행형, REFACTOR 는 별도 리팩터링 태스크로 분해가 의도" 주석 (drift 가 아니라 단위 차이임을 고정).
  - **테스트영역 감사 P3 — macOS CI 차단 승격** — `test.yml` run-all-macos 의 `continue-on-error: true` 제거 (관찰 기간 green + darwin 이 주 개발 환경).
  - **빈틈2 — verify 테스트=spec 커버 점검** — api-spec 에 추가·변경된 제공 엔드포인트별 테스트 케이스 존재 대조, 미커버는 evidence.md `## 미커버 엔드포인트` 권고(비차단·graceful).
  - 기각 기록: TDD P3-① whitelist 협소(=#195·#209 로 기해소, memory stale)·R-4 무관 러너 면제(F-3 self-report 클래스 WON'T-FIX 정합)·e2e staleness stamp·init-project phases 직접 유닛(e2e 가 커버, 투자 대비 낮음).
- **trivial 단축경로 외부 실주행 dogfood — 완주 차단 결함 3건 적발·해소** (완주율 레버, 평가 6.7 도달-14% 공략) — 외부 fixture repo(todo.sh CLI)에 신규 소형 기능(stats 명령)을 실제 lifecycle 로 진입시켜 spec→trivial 제안·승인→(clarify·plan SKIP)→decompose→implement(Phase B PASS·C READY_TO_MERGE)→verify **완주 실증**. 발견 3건 전부 fix:
  - **★ 발견 #3 (핵심 — false-block 4호)**: `run-verification.sh` whitelist·`extract-test-commands.sh` fallback 정규식이 `bash scripts/` **접두 하드코딩** — 플러그인 자기 repo 레이아웃 편향. downstream 표준 `bash tests/test-x.sh` 가 추출 0건(NO COMMANDS) 또는 SKIP(PARTIAL) → **실행-근거 게이트 불인정 → 정직한 외부 완주가 커밋 deny → BYPASS 강요**. 외부 완주를 게이트가 직접 막던 문. 두 곳 `(scripts|tests?)/` 확장(anti-footgun 성격이라 상대경로 테스트 디렉토리 확장 안전 — 절대경로·`lib/` 여전히 차단). 회귀: `test-verifying-automation` T2.g(extract 층, RED→GREEN)·T2.h(whitelist 층 YAML 주입 잠금). **fixture red-green 실증**: fix 전 `VERIFY: PARTIAL` → fix 후 `VERIFY: PASS`.
  - **발견 #1**: decomposing trivial 오판 안전망 기준 "AC ≥ 3 또는 파일 ≥ 2" 가 TDD 최소 구성(코드1+테스트1=2파일·회귀 AC 포함 must 3건)에 **항상 걸리는 false-trigger** — 전 trivial 재확인 유발로 단축 이득 상쇄. "must AC ≥ 4 또는 구현 파일 ≥ 2(테스트 제외)" 로 보정.
  - **발견 #2**: acceptance-criteria.md 를 bullet(`- **AC-1**:`) 포맷으로 쓰면(템플릿은 `### AC-1:` 헤더 — LLM 흔한 위반, 실주행에서 재현) `emit-context` AC 요약이 **빈 문자열로 조용히 degrade** + validate-context 도 통과. bullet 겸용 파싱 + 추출 실패 시 stderr WARN. 회귀: `test-emit-context` T1.j(bullet 추출)·T1.k(WARN 발화).

## [1.47.1] — 2026-07-16

### Fixed
- **소비 IF(api-spec-consumer) 정·역 쌍 복원 + advisor 연결 진단 신설** — ① **C2 소비 축**: 재실측 결과 memory 의 "빈틈1" 은 대부분 stale(8g consumer 생성·frontend-architecture 참조 정정 기완료, 8f KIND 2·4 한정은 정당 — UI/Mobile 은 제공 API 없음)이었고, 진짜 잔여는 **소비 IF 축만 정방향(Step 5.6·design-interface) 설계뿐 역방향·계약 미배선** — verify 역방향 안전망 추출 대상에 외부 API 소비 호출 없음 · emit-context §6 계약 · implementing 계약 목록 전부 consumer 0건. UI/Mobile 프로젝트에서 신규 외부 API 호출이 추가돼도 `api-spec-consumer.md` 대조 없이 통과하는 반쪽 안전망이었다. verify(추출 대상 "외부 API 소비 호출" + 대조 대상 consumer)·emit-context contract·implementing 계약 3곳 대칭 복원. teeth: `test-interface-routing-doc` AC-15(verify 소비 축, grep `-c`≥2)·AC-16(계약 대칭) + `test-emit-context` T1.f2(consumer §6 emit, RED→GREEN). ② **C3 advisor 연결 진단**: advisor() 미연결이 2세션 연속 "자체검토만" 무음 fallback — 협의 의무 체계가 도구 부재로 조용히 공회전. 공식 문서 조사(advisor=서버사이드 도구) 기반으로 `advisor-ko` 에 **연결 진단 §**(4원인: pairing 무효(advisor 는 main 과 동급 이상 — main 상향 시 조용히 깨지는 함정)·main 미지원·비-Anthropic API·`CLAUDE_CODE_DISABLE_ADVISOR_TOOL`) + 사용자 재연결 안내 1회 의무 신설. teeth: `test-auto-advisor` AC-6.
- **verify-exec-gate 잔여 backlog 4건 일괄 종결** (PR #195 알려진 잔여 — [`project_verify_exec_gate`] §잔여):
  - **B4 inject-evaluator-timestamp 개행 융합 fix** — BSD sed `a\` 가 삽입 텍스트 뒤 개행을 안 붙여 `**timestamp**: ...Zbody` 로 다음 줄이 흡수됐다(실측 재현 — 기존 T2.e 는 status 가 마지막 줄이라 미검출). awk print 전환(BSD/GNU 무차이) + 회귀 T2.e2(중간 삽입 융합) 신설.
  - **B2 심층 필터 통합 잠금** — is_error·PASS/PARTIAL 혼재는 단위(T9·T10 인라인)만 있었고 pretool 훅 전체 파이프는 미잠금. 파일 fixture 2종(`pretool-verify-exec-error`·`-partial-mixed`) + test-pretool T2c·T2d 신설 — 둘 다 deny 실증.
  - **B1 스코프 이관 규약 명문화** — NEEDS_CONTEXT 트리거 5(whitelist 외 파일) 처리가 dispatch context 수기 보강으로 새면 ① tasks.md(SoT) drift ② emit-context 재실행 시 증발 ③ 후속 wave outputs-disjoint 판정이 낡은 outputs 로 계산 → R11 git race. implementing-ko 에 4스텝 규약(tasks.md 먼저 갱신 → emit-context 재실행+worktree 라인 재갱신 → 미완 wave disjoint 재판정 → `SCOPE-MOVED:` 기록) 신설. teeth: test-emit-context T1.h(규약 배선 grep, `-c`=1)·T1.i(재실행 멱등 — 수기 편집 증발 cksum 실증).
  - **B3 roadmap §auto stale 서술 정정** — V1 의 "§auto 차단 면제" 서술에 후속 정정 인용(무조건 면제는 v1.45.0 에서 제거 — 자기발급 면제표, 실행-근거 동반 시에만 통과) 각주.

## [1.47.0] — 2026-07-16

### Fixed
- **R-1/R-2 실행-근거 게이트 run-all.sh 미인식 false-block 해소** — 플러그인 자기 repo self-maintenance 의 정식 검증 러너는 전체 스위트 `run-all.sh` 인데, `_verify_exec_evidence` 러너 클래스가 `run-verification.sh`·pytest 류만 인식해 **run-all 95/95 통과 세션이 커밋·PR 에서 deny** 됐다(20260716 dogfooding 실전 적발 — false-block 은 BYPASS 남발을 유발해 게이트 신호 자체를 희석, heredoc false-block #199 와 동일 클래스). 해소(토큰 계약 단일 유지): ① `run-all.sh` 가 성공 시 `VERIFY: PASS`·실패 시 `VERIFY: FAIL` 을 마지막 줄로 출력(소비자 전부 exit-code 기반 + 기존 출력에 `VERIFY:` 혼입 0 실측 — 안전) ② 러너 클래스에 `bash \S*tests/run-all\.sh` 추가 — **좁은 앵커**(downstream 무관 `./run-all.sh` 불인정, 위조 표면은 기존 run-verification.sh 와 동일 클래스로 비확대) ③ pretool deny 메시지에 self-maintenance 대안 안내 1줄. 게이트 출력검사 로직(jq negative check) 무변경. 회귀: `test-exec-evidence.sh` T14(인식)·T15(좁은 앵커 잠금)·T16(FAIL 토큰 negative) + 신규 `test-run-all-verify-token.sh` 3건(sandbox 실행 기반 토큰 계약 + 앵커 배선 grep, `-c`=1 실측). advisor 미연결 — 자체검토만 명시(원칙 5).
- **batch Phase 3 per-FR verify·code-review 뭉개짐 3층 해소 (개별 산출물 강제)** — `/start-all` Phase 3 는 FR 마다 verify·code-review 를 돌리지만 **개별 산출물이 뭉개졌다**. 3층 원인: **(1) 지시** — Phase 3 스텝 2~4 에 "(FID 기준)" 명시가 없어, 바로 아래 Step A/B/C 의 "batch 전체 대표 FID 로 **1회** 통합" 패턴을 verify·review 에까지 일반화(테스트는 suite-global 하게 느껴져 특히 유혹)하기 쉬웠다. **(2) 내용** — `requesting-code-review-ko` 의 `BASE_SHA=git log|grep "Task 1"|head -1` 이 공유 `feat/<BATCH_ID>` 브랜치에서 **가장 오래된** Task 1 커밋을 잡아, FR-2 의 `review.diff` 가 FR-1 변경까지 포함 → **이름만 per-FID, 내용은 blended**. **(3) teeth 부재** — `batch-state.sh` 가 queue Status parity(IMPL_DONE 토큰)만 검사하고 per-FID `evidence.md`·`review-request.md` **존재는 미검증** → 뭉개진 채 batch PR 통과. 해소: `start-all.md` Phase 3 에 **per-FR≠batch-level 경계 박스** + 스텝 1a(`git rev-parse HEAD > .specops/<FID>/review-base.sha` — 각 FR 구현 직전 base 고정) + 스텝 2~4 **(FID 기준)** 명시 + 스텝 6 산출물 존재 확인 후 IMPL_DONE. `requesting-code-review-ko` 에 **§batch base 격리 분기**(review.diff base = `review-base.sha`, 부재 시 `HEAD~1` fallback). **teeth(3층 대칭)**: `batch-state.sh` 가 IMPL_DONE FID 마다 `review-base.sha`(layer 2 내용 격리) **AND** `evidence.md` **AND** `review-request.md`(layer 3 존재) **3종** 존재를 하드 요구, 부재 시 `[산출물 누락]` + exit 1 로 batch PR 차단. ★ **layer 2 대칭화**(adversarial 적발): review-base.sha 를 teeth 에 안 걸면 step 1a 누락 시 `HEAD~1` silent fallback 인데 review-request.md 는 생성되니 존재-teeth 통과 → **내용 뭉개짐이 조용히 재발**. IMPL_DONE 한정(MERGED=타 사이클 shipped, batch 전용 review-base.sha 미보유 → legacy false-block 방지). 전파: `e2e-test-ko` V24·`test-batch-orchestration` T5 에 3종 시뮬 seed. 회귀: `test-batch-state.sh` T2.b(review-request 부재 차단·완전 FID 미보고)·T2.c(FID 디렉토리 부재)·**T2.d(review-base.sha 만 부재로 차단 — layer 2)**·**T2.e(§batch spec+review-base.sha → 문서화 BASE_SHA 스니펫이 파일 내용으로 resolve, HEAD~1 미사용 실행검증)** 신설. GNU/BSD(gawk·mawk·ggrep) 이식성 확인.

### Added
- **신규 trivial 단축 경로 — 소작업 탈출구 신설 (완주율 레버)** — 2026-07-14 평가(6.7/10)가 지목한 **완주율 14%의 지배 원인**: `trivial` 축약이 유지보수 분기 전용이라, 1파일 소규모 **신규** 작업도 spec→clarify→plan→decompose→implement→verify 6단계 의식을 강제당했다(실측 이탈: CouponWake 1라인 픽스가 6분 의식 후 수동 커밋 · IKEN spec 15초 후 마찰 맞고 Excel 이탈). 이제 `specifying-ko` 가 신규 분기에서 설계 승인 직후 예상 산출이 **단일 파일·소규모**면 사용자에게 축약을 **명시 제안**하고, **사용자 승인 시에만** `§유형: trivial` 부여 → **clarify·plan ceremony 만** 건너뛰고 `decomposing-ko` 직행한다. `decomposing-ko` 는 `plan.md` 부재를 trivial 로 감지해 spec+AC 로 **단일 태스크 tasks.md** 를 경량 합성(implementing 무변경 — DAG 계약 유지). ★ **teeth 불변**: decompose·implement·**verify 실행-근거 게이트·TDD·security 는 정상과 동일** — 사용자가 규모를 오판해도 검증 teeth 가 안전망이다. 축약되는 것은 오직 설계 ceremony 뿐. **경제성-안전 설계**: 새 훅·게이트·chain edge·사용자 개념 0개 신설 — `specifying`/`decomposing` body 조건 분기 + 기존 R-5 trivial-skip·AC-R 면제 **재사용**(primary edge 불변이라 chain.yaml·메타목록 무변경). SKIP 은 session-progress 에 `완료` 위장 없이 정직 기록. 회귀: `test-trivial-new-shortcut.sh` 14건 — form 검사 + **실행 어서션 3건**(실제 파이프라인에서 clarify·plan provably SKIP · ceremony 산출물 실제 부재 · R-5 거버넌스 미발화). FID 20260714-trivial-new-shortcut

## [1.46.0] — 2026-07-14

### Fixed
- **LLM eval 이 유지보수 신호를 측정하도록 fixture 정확화** — `#198`(sandbox 파일 시드) 후에도 `maint-2`·`docs-1`·`new-4` 가 FAIL 이던 것을 stream-json 진단으로 원인 규명. `new-4`("기존 도구 업그레이드")는 모델이 `analyzing-ko`(유지보수)를 정확히 호출 — 구 `expect_skill`(specifying-ko)이 버그였다. `maint-2`(작으면 스킵/크면 timeout)·`docs-1`(자문 후 스킵)은 eval 로 안정적 PASS 가 어려운 **경계 케이스**로 `note` 에 정직히 기록(억지 green 안 만듦). 성과: `maint-1`·`maint-3`·`new-4` 가 `analyzing-ko` 감지 — 전엔 파일 부재로 **100% `none`**(측정 자체가 안 됐다). `judge()` FAIL 사유 구분(`FAIL:skill`/`FAIL:flag`)으로 "skill 정답·약속어 누락"이 드러난다. FID 20260713-eval-sandbox-seed

### Added
- **mutation 커버리지 게이트 강제화 + governance-lib 측정 정확화** — mutation testing 인프라(`mutation-score.sh`)가 있으나 (a) run-all 미포함=수동 (b) 타겟 명령이 stale 해 governance-lib 를 **32%** 로 오측정했다(`test-lib && test-rules` 만 돌려 `_verify_exec_evidence`·`_strip_heredoc_bodies` 미커버). 전체 governance 스위트로 정정 → **55%**(15개 false rot 제거). `MUTATION_MIN_SCORE` threshold 추가(미설정 시 기존 동작 — 하위호환)하고 `llm-smoke.yml` 주간 cron 에 mutation job 배선(secret 불요·항상 실행, MIN=55) — run-all 은 ~6분 부담이라 cron. `test-conventions-bash.md` §5 에 grep 앵커 tautology 규약(`grep -c '<앵커>' == 1`) + 실측 함정 3건 문서화(리뷰 규율, 자동 linter 는 정적 불가). ★ 리뷰가 이 게이트 자체의 hollow verification 2건 적발(testcmd 파손 시 100% 거짓 통과 → baseline sanity self-check, threshold 무테스트 → T15·16·17 추가). FID 20260714-mutation-ci-gate

## [1.45.0] — 2026-07-14

### Added
- **실행-근거 gate — 자기보고 면제 3경로 균일 조임** — R-1/R-2(commit·PR 전 verify) 게이트가 **자기보고만으로 열리던** 구멍을 막았다. 기존엔 session-progress 에 수기로 쓴 `/verify PASS` 줄 · evidence.md 스탬프 · Skill 호출 중 **하나만 있으면** 면제됐고, 셋 다 모델이 스스로 쓰는 텍스트라 사실상 자기발급 면제표였다. `governance-lib.sh` 에 `_verify_exec_evidence` 신설 — transcript 의 `tool_use` ↔ `tool_result` 를 `tool_use_id` 로 join 해 **검증 러너가 실제 실행되어 `VERIFY: PASS` 를 출력했는지** 확인하고, 3경로 **전부** 이 실행 증거를 요구한다. `VERIFY: PARTIAL`·`FAIL`·`is_error` 결과와 command-only 위조(`echo pytest`)는 불인정. 판정 불가(transcript 부재·jq 실패)는 fail-open 으로 기존 동작 유지. FID 20260713-verify-exec-gate
- **`run-verification.sh` 다언어 러너 확장** — 화이트리스트가 `bash scripts/*.sh` 만 실행하던 탓에 pytest·npm 프로젝트는 **항상 `VERIFY: PARTIAL`** 이었고, 실행-근거 gate 가 요구하는 PASS 증거를 구조적으로 낼 수 없었다. `pytest`(`python -m pytest` 포함) · `npm|pnpm|yarn (run) test` · `go test` · `cargo test` 를 **선두 앵커(`^`) 고정** 패턴으로 추가 — `echo pytest`·`foo && pytest`·`rm -rf / # pytest` 류 위장은 계속 SKIP. 한계 고백: `go test ./...`(`..` 가드) · `npm run test:unit`(`:`) 은 여전히 미지원. 실패 경로(`VERIFY: FAIL`)도 회귀 테스트로 영구 고정.
- **LLM eval sandbox 파일 시드 (`seed_files`)** — `maint-*`·`docs-1`·`new-4` fixture 가 실재하지 않는 파일(`scripts/slug.sh`·`README.md`)을 참조해, 모델이 파일 부재를 확인하고 정직하게 중단한 것을 eval 이 `got=none` → FAIL 로 오판했다. **PR #57 이래 "신호 감지 eval" 이 유지보수 신호를 한 번도 측정한 적이 없었다** (baseline 대조로 선재 결함 확정). `setup_sandbox` 에 `seed_files`(선택 필드) → sandbox 생성 + **git tracked**(모델이 `git ls-files` 로 확인) 추가. `test-llm-eval.sh` 에 fixture↔seed 정합 정적 검사(T16) 신설. `judge()` FAIL 사유 구분(`FAIL:skill`/`FAIL:flag`/…) — skill 을 맞혔는데 flag 로 떨어진 것을 skill 오답처럼 보이던 문제 해소. FID 20260713-eval-sandbox-seed

### Removed
- **`§auto` 무조건 면제 제거 (⚠️ 행동 변경 — 거버넌스 조임)** — `pretool-governance.sh` 가 spec.md 의 `**§auto**: true` 라벨만 보고 실행-근거 검사에 **도달하기도 전에** allow 하던 블록을 삭제했다. 그 라벨은 모델이 spec.md 에 쓰는 것이라, 무인 진입(`/start-auto`·`/start-all-auto`)이면 게이트가 통째로 무효화됐다. `§auto` 의 의미는 "가역 게이트 자동 통과"(사용자 확인 생략)이지 "검증 면제"가 아니다. 무인 모드도 chain 에 `verifying-evidence-ko` 가 있어 verify 를 실제 실행하므로 **정직한 무인 흐름은 실행 증거를 남기고 그대로 통과**한다(e2e·batch 회귀 PASS). 남는 면제 4종: `SPECOPS_GOVERNANCE_BYPASS=1` · docs-only · `.specops/` 부재(관할 한정) · fail-open.

### Changed
- **비-소프트웨어 요청은 lifecycle 에 진입하지 않는다 (⚠️ 행동 변경 — 진입 게이팅)** — "신제품 소개 PPT 12장 만들어줘"·"요구사항 정의서 작성해줘" 처럼 **repo 밖 산출물**만 만드는 자연어 요청이, 그동안 메타 skill 의 신호 감지("만들어줘")에 걸려 chain(spec→clarify→plan→implement→verify)에 통째로 포획됐다. **테스트할 코드가 없으니 후속 단계가 전부 공회전**했고, 실측 이탈 2건(`sales-ppt` PPT 12장 · `iken-webapp` 요구사항 133건)은 둘 다 spec 에서 사망 — 후자는 사용자가 Excel 로 이탈했다. 이제 이런 요청엔 **1줄 고지**("코딩 작업이 아니라 판단해 lifecycle 을 진입하지 않았습니다")와 **`/start <설명>` 강제 진입** 안내가 나간다 — 판정이 틀렸다면 슬래시로 즉시 뒤집을 수 있다(`/start` 는 무조건 직행. `commands/` 무변경 — slash SoT 불침범).
  - **무손상 — repo 내 파일은 진입 유지**: 코드·설정·스크립트·스키마는 물론 **README·CLAUDE.md 등 문서 수정도 그대로 chain 에 들어간다**("README 설치 안내 업데이트해줘" → 유지보수 진입). 문서만 고치려다 코드까지 건드리는 일이 흔해서다. 배제는 **명백할 때만**이고 **애매하면 호출**한다 — 진짜 코딩 작업을 놓치는 쪽(false-negative)이 과잉 발동보다 훨씬 나쁘다. "1% 가능성이라도 호출" 정신은 유지(**블랙리스트** — 화이트리스트 전환 아님). `specifying-ko` 의 "인지된 단순성과 무관하게 전부 프로세스를 거친다" 원칙도 무변경(chain 단축 없음).
  - **⚠️ 한계 고백 — 정적 통과는 실효 증명이 아니다**: 이 게이팅은 **산문이 LLM 을 설득하는 구조**다. 자동 테스트(`run-all` 94/94 · `test-meta-skill.sh` T6.a~d)가 증명하는 것은 **배제 문구가 존재한다**는 사실뿐이고, LLM 이 실제로 그렇게 행동하는지(**실효**)는 `bash scripts/tests/llm-eval/run-evals.sh` 로만 관찰된다 — **토큰 비용 때문에 run-all 비포함·수동 실행**이다. 신규 fixture 3건(`nonsw-1`·`nonsw-2` 배제 / `docs-1` 진입 유지 가드)을 그 수동 계층에 추가했다. 비결정론이 의심되면 `LLM_EVAL_RUNS=5` 로 성공률을 본다. FID 20260713-signal-coding-gate
- **문서 drift 화해 (3곳)** — (a) `CLAUDE.md` 거버넌스 엔진: 면제 서술을 4종으로 정정 + 실행-근거 gate 문단 신설. (b) `verifying-evidence-ko/SKILL.md`: "whitelist 미통과 (npm/pytest 등)" · "`bash scripts/...` 외 명령만 쓰면 **항상** PARTIAL" 이 다언어 확장 이후 **거짓**이 되어 실제 러너 목록·잔여 SKIP 형태·gate 연동으로 갱신. (c) `pretool-governance.sh` 근거 주석: `/implement` 의 **태스크별 중간 커밋은 verify 이전이라 실행 증거가 없어** 정직한 흐름이어도 deny→BYPASS 경로를 탄다는 설계된 비용을 명시(다음 독자 오도 방지).

### Fixed
- **유령 에이전트 서술 정정 + `xref_resolve` bare 토큰 확장** — harness skill 4종(`generator-evaluator-ko`·`sprint-contracts-ko`·`context-resets-ko`·`file-based-communication-ko`) + `advisor-ko` + `templates/` 가 **존재하지 않는 에이전트 6종**(`specifier`·`clarifier`·`planner`·`analyzer`·`task-decomposer`·`verifier`-ko)을 서술했다. `generator-evaluator-ko` 의 "Generator 4 / Evaluator 4" 는 **이름이 아니라 구조가 허구** — 명세·설계·분해·검증은 에이전트가 아니라 skill 이 메인 세션에서 수행한다. 실재 `agents/` 7종(Generator: `implementer-ko` / Evaluator: `spec-reviewer`·`code-reviewer`·`plan-reviewer` / self-config: `red-team`·`blue-team`·`auditor`)으로 교체. **근본 원인**: `xref_resolve` 가 `specops-ko:` prefix 토큰만 수집한 탓에 bare 로 서술된 유령이 검사망 밖이었다(93개 테스트 전량 통과의 원인). bare `-ko` 토큰 + `templates/` 스캔으로 확장하고 플러그인명·upstream 참조 4종 allowlist 로 오탐 차단. 원칙(Gen↔Eval 분리 — `role: evaluator` Write/Edit 박탈)은 무변경. FID 20260713-ghost-agent-drift
- **heredoc 본문의 git 예시를 실제 명령으로 오인하던 false-block 제거** — `grep -E` 가 줄 단위라 멀티라인 Bash command 의 heredoc 본문 줄(`cat > spec.md <<EOF ... git commit ... EOF`)도 R-1/R-2 트리거에 매칭됐다 → skill·plan·spec 에 git 예시를 쓰는 정직한 작업이 차단되고 BYPASS 남발을 유발해 실행-근거 gate 의 신호를 희석했다. `_strip_heredoc_bodies()` 로 트리거 검사 **입력만** 전처리(정규식 무변경 — evasion 방어 불변, 리터럴 바이트 동일). 셸 실행자(`bash`·`sh`·`eval`) heredoc 본문은 실제 실행되므로 제외하지 않아 **F-3 표면 불변**(우회 표면 19종 탐침·strip 이 진짜 커밋 숨긴 케이스 0건). 미종료·판정불가 시 원본 반환(fail-safe — 차단 우세). FID 20260713-heredoc-false-block

## [1.44.0] — 2026-07-13

### Changed
- **implementing-ko 모델 라우팅 섹션 drift 화해** — 커밋 97c672b("서브에이전트 모델 라우팅 고정 — 리뷰=fable·개발=opus") 이후 stale 했던 `## 모델 티어 라우팅` 섹션(tasks.md `tier:` 필드→부모가 model 파라미터 동적 결정, 미배선 dead spec)을 실제 고정모델 현실로 화해. `## 모델 라우팅 (역할별 고정)` 로 재작성 — implementer=opus·evaluator=fable·self-config=inherit frontmatter 단일 소스, 품질 편향(비용 다운그레이드 미채택) 명시, L231 오기(implementer inherit↔실제 opus)·BLOCKED "더 강한 모델" 모순 제거. wshobson/agents PluginEval 흡수 분석의 model-tier 항목이 이미 완료(97c672b)였고 doc drift 만 잔여였음을 반영. (#194)

## [1.43.0] — 2026-07-13

### Added
- **LLM eval N-run 신뢰성 측정 (`LLM_EVAL_RUNS`)** — wshobson/agents PluginEval Layer3(Monte Carlo) 아이디어를 bash 로 이식. 기존 `run-evals.sh` 는 fixture별 1회 실행(+retry cap=1)이라 확률적 LLM 동작의 flakiness 를 못 잡고 retry 가 오히려 은폐했다. `LLM_EVAL_RUNS=N`(N>1) 시 retry 없이 N회 반복 → per-fixture 성공률·FLAKY(<80%)·총괄 평균활성률 리포트(비차단 exit 0). 기본 N=1 은 기존 단발 동작 완전 무변경, 경계 케이스(`expect_any`)는 집계 제외. FID 20260713-llm-eval-nrun (#192)
- **SKILL.md 정적 밀도/bloat lint (T10)** — wshobson/agents PluginEval Layer1(BLOATED_SKILL·OVER_CONSTRAINED) 이식. `test-skill-conventions.sh` 에 (a) bloat(>800줄, specops "800 max" norm — e2e-test-ko 문서화 예외) 예외 밖 FAIL 회귀가드, (b) 디렉티브 밀도(`discipline: true` 제외, 임계 25) 초과 시 INFO(FAIL 아님) 추가. 임계를 현 최댓값(22) 위로 두어 현재 0건 flag·미래 폭증만 포착 — OVER_CONSTRAINED 판단은 `discipline: true` marker 를 통해 사용자에게 남긴다. FID 20260713-skill-density-lint (#193)

### Changed
- **CLAUDE.md 서브시스템 3영역 반영** — 최근 대형 서브시스템(self-config 적대감사 red/blue/auditor·design-first 대칭 Step 5.5/5.6·학습 루프 gbrain/freelog)을 CLAUDE.md 에 문서화 (#191)

## [1.42.0] — 2026-07-12

### Added
- **화면(UI) E2E 검증 루프 폐합 — DB lifecycle 대칭 (감사 P1+P2)** — 화면(screens)이 design-first(Step 5.5)로 그려지고 구현자 전달까지만 닫히고 사후 검증(분해·리뷰·verify·게이트)이 비어 UI 웹앱이 브라우저 무검증으로 PR 통과하던 3중 비대칭을 DB lifecycle(#152) 패턴으로 대칭 복제해 폐합. verifying-evidence 역방향 net 에 screens/ 대조, code-reviewer UI/화면 관점(조건부), integration-test UI/사용자흐름 detection 신호(기존 백엔드 OR 유지), performance-test Web Vitals(LCP/CLS/FCP) 신호 추가. UI 표면 검출 시 downstream 스택(Playwright/Cypress) E2E 위임(e2e-runner 선택적·Step 2 env-check 재사용). **detection·delegation 은 플러그인 강제, 브라우저 E2E execution 은 downstream/manual**(플러그인 인프라 부재 — advisor: e2e-runner 하드 dispatch 기각, 사용자 전역 에이전트라 aspirational). 4 신호를 계약 테스트 `test-ui-e2e-signals.sh`(앵커 리터럴 + reverse-observe)로 잠금(aspirational 방지). FID 20260712-ui-e2e-loop-closure (#189)

## [1.41.0] — 2026-07-12

### Fixed
- **테스트 인프라 false-PASS/silent-skip 봉쇄 (테스트 영역 감사 P1·P2)** — 3각도 테스트 감사가 되돌려-관찰로 실증한 "조용한 거짓 통과" 표면 3건 근본 봉쇄:
  - **gbrain tautology + harness canary (P1, #185)** — `test-gbrain.sh` T2.b·T2.c 가 `bash -c` 블록 마지막 `rm`(항상 exit 0)에 grep 판정을 삼켜 프로덕션을 망가뜨려도 통과하던 tautology 를 판정-캡처(rc→rm→exit rc)로 정정. `harness.sh:5` 오파일명 canary(복붙 시 source-실패 false-PASS 유발) 정정. FID 20260711-test-gbrain-tautology
  - **harness 로드 가드 (P2-①, #186)** — harness source test 가 함수 로드 실패 시 카운터 미증가로 0 assertion 인데 조용히 exit 0 하던 구멍을, source 다음 줄 로드 가드(`command -v finish || exit 1`) 34개 삽입으로 봉쇄. finish 표준화(감사 원안) 대신 로드 가드 채택(advisor 협의 — tail 무접촉·계약 테스트 강제력). 계약 테스트 `test-harness-load-guard.sh`. FID 20260711-harness-load-guard
  - **run-all glob 완결성 계약 (P2-②, #187)** — run-all aggregator 가 test 서브디렉토리를 for 루프에 하드코딩 편입해 미등록 subdir 에 test 추가 시 조용히 스킵하던 구멍을, 완결성 계약 테스트(find 실제집합 ⊆ run-all for-루프 grep 커버, run-all 단일 SoT)로 봉쇄. run-all 실행 경로 무접촉(advisor 협의 — 릴리즈 게이트 불안정화 방지) + L4 stale 주석 정정. `test-run-all-glob-completeness.sh`. FID 20260712-runall-glob-completeness

## [1.40.0] — 2026-07-11

### Added
- **batch 오케스트레이터 런타임 커버리지 (G0 해소)** — `/start-all` batch 상태기계를 2층으로 검증: ① 무료·상시 결정적 시뮬 `scripts/tests/test-batch-orchestration.sh`(queue 초기화·PLAN_DONE 전이·재진입 보존·batch-state 게이트 통합, start-all.md 근거 라인 주석 의무) ② 유료·수동 e2e `[S8] BATCH`(격리 repo Phase 0~1 실주행·§batch halt·완료 게이트 실증, V22~V24). e2e V 개수 21→24 동기. start-all 감사 G0 해소. FID 20260711-g0-batch-e2e (#182)

### Fixed
- **TDD RED 증거 규약 강화 (감사 P1 3건)** — TDD 3각도 감사에서 RED 관찰이 카운트 요약 주장에만 의존(실증 7 FID 중 raw 출력 인용 0, GREEN 과 비대칭)함을 확인. 앵커 규약 `RED 실측 출력`·`FAIL 라인 ≤10줄` 을 5소비처(tdd-ko 합리화 차단표·implementer-ko·verifying-evidence·dispatch-context 의무표·tasks.md 스텝2)에 배선하고 문구 계약 테스트 `test-tdd-red-evidence.sh`(15케이스)로 상시 잠금. templates/tasks.md test_command "optional" 모순 정정(emit-context 게이트 SSOT) + implementer-ko 죽은 "git log 증명" self-check 교체. FID 20260711-tdd-red-evidence (#183)

## [1.39.1] — 2026-07-11

### Fixed
- **전체 점검 P3 Low 10건** — 분석 단계 advisor 계약 실배선(impact-analysis §4 신설 + R-5 죽은 타깃 impact-analysis.md 교체) · init 종료 안내 이음새(/start-foundation·/design-screens·/design-interfaces·/status) · Phase 8e 클라이언트 스토리지 안내 · design-interfaces 커밋 참조 · agents drift 3건 · generator-evaluator 잔재 · start-all 문서 3건 · README R-6 정정 (#181)

## [1.39.0] — 2026-07-11

### Added
- **`scripts/batch-state.sh` — 첫 batch 인프라** — `/start-all` queue↔requirements parity read-only 감지(미완·드리프트·FR-ID 중복, 2-테이블 분할 queue 견딤). Phase 3 완료 하드 스캔 게이트 배선: exit 1 → "그래도 batch PR? [y/n]"(의도적 부분 진행 허용 — 주권), §auto 무인 정지점. 실물 batch 산출물에서 드리프트 5건+미완 3건 검출 실증. start-all 감사 F-4·F-5 해소. FID 20260710-p2-batch-state (#180)

### Fixed
- **전체 점검 P1 — 경계면 전파 누락 5건** — ① DESIGN.md 템플릿 Border 행(9색 헬퍼 no-op 해소) ② Phase 7 html `{{화면 제목}}` 치환 ③ 가정 다이제스트 "자동 결정 인터페이스" 3소비처 수집 ④ verify 역방향 안전망 클라이언트 스토리지 커버 ⑤ README `/design-interface(s)` 반영+footer 3커맨드 (#178)
- **P2 규약 3건** — Phase 11 그룹③ 팔레트 재주입(미편집 단서) · data-model §1 하이브리드 복수 표기 · Step 5.6 인터페이스 dedup (#180)

## [1.38.0] — 2026-07-10

### Added
- **인터페이스 설계 클라이언트 스토리지 축** — Step 5.6(=start-all batch·단일 /start 공용) + `/design-interface(s)` 독립 슬래시에 "클라이언트 영속 데이터(localStorage·IndexedDB)" 축 추가. 기존 2축(제공 HTTP API / 외부 소비 API)만으로 skip 되던 서버 없는 프론트 앱(예: weekflow)도 화면 Interactions·requirements FR 이중 근거로 `data-model.md` 자동 도출. HTTP api-spec 무변경(혼입 금지), 순수 UI·CLI 로직은 skip 유지(비확대). 라우팅 정합 15케이스. weekflow dogfooding 실결함 발견→수정. FID 20260710-if-client-storage-axis (#177)

## [1.37.0] — 2026-07-10

### Added
- **`/design-interface(s)` 인터페이스 설계 독립 슬래시** — 화면 `/design-screen(s)` 대칭. 무스크립트 대화 루프로 `api-spec.md`·`data-model.md` 마스터 섹션 갱신(덮어쓰기 금지), 화면 `Interactions`→API 도출(design-first 결합), 제공/소비 API 구분, 3경로 분업 cross-ref + `test-interface-routing-doc.sh` 정합 검증. FID 20260710-design-interface-slash (#176)
- **Phase 11 v2 — 인터뷰·가정 다이제스트·깊이 기준** — 그룹별 사전 인터뷰(상한·결정급 우선·"모름/나중에"·질문 스킵)로 비약(미질문 가정) 차단, 가정 전건 번호 목록+★ 게이트·PRD 말미 다이제스트 기록으로 투명화, 최소 깊이 기준 v2(must 빈 셀 금지·M1 FR 분해 / should NFR 수치)로 허접 차단, 무인 degrade(e2e·§auto). enrich 스위트 44케이스. FID 20260710-init-p11-quality (#174)

### Fixed
- **init-project 화면 스캐폴딩 DESIGN.md 팔레트 미반영** — Phase 7·`design-screen.sh` 가 DESIGN.md 색상을 반영 안 하던 것(Phase 7=0색, design-screen=Primary만)을 공유 `_inject_design_palette` 9색 매핑 헬퍼로 해소(미확정 색은 skip→기본값 유지). FID 20260710-init-p11-quality 계열 (#175)
- **session-progress 첫 append 오염** — 신규 프로젝트 첫 lifecycle 커맨드 시 rehydrate 블록에 템플릿 예시가 딸려 들어가던 잔여 결함(#172 후속)을 안내문·예시를 삽입 anchor 위로 이동해 해소. 회귀 테스트는 실 파이프라인으로 생성 (#173)
- **V21 placeholder 스캔 규약 표기 allowlist** — `.specops/<FID>`·`screens/<name>` 류 규약 표기를 placeholder 로 오검출하던 것을 스캔 SoT(`scan-enrich-placeholders.sh`) allowlist 로 해소 — 정직 보강과 양립 (#171)

## [1.36.0] — 2026-07-09

### Added
- **init-project Phase 11 LLM 보강 패스** — bash 10 Phase 종료 후 LLM 이 13종 산출물을 개발 기준 문서 수준으로 보강 (그룹 3묶음 승인 + 사실성 계약 + 재커밋). 브레인스토밍 메모 존재 시 PRD 6필드 초안 합성. `--enrich` 소급 경로 (placeholder 잔존 문서만 — 멱등). e2e V21 placeholder 스캔. 계약 스캔 테스트 `test-init-project-enrich.sh` 신규. bash 레이어 0 diff. FID 20260709-init-project-llm-enrich

## [1.35.0] — 2026-07-06

### Added
- **서브에이전트 모델 라우팅 고정** — 서브에이전트 단계의 모델을 명시 고정(메인루프 스킬은 `/model`이 지배하므로 대상 밖). `implementer-ko`(개발+TDD 5스텝) `inherit → opus`, `code-reviewer-ko`·`spec-reviewer-ko`·`plan-reviewer-ko`(리뷰) `inherit → fable`. 메인루프(브레인스토밍·specifying·analyzing·planning·verify)는 세션 `/model` 따름. `red/blue/auditor`(security-scan 감사)는 스코프 밖 inherit 유지. PR #169

## [1.34.1] — 2026-07-03

### Fixed
- **init-project 생성 문서의 오인 예시·자기모순·유령행 정리** — 라이브 부트스트랩 산출물 내용 검토에서 발견한 3결함. **A**: `data-model`(`users`/`orders`/`products`)·`api-spec`(`/v1/users`)이 프로젝트 무관 e-commerce 예시인데 placeholder 마커 없어 실제 설계로 오인 소지 → "예시 — 실제 도메인으로 교체" 경고 배너(architecture/front/back은 `<Redux/Zustand>` choice-placeholder라 이미 자명, 미대상). **B**: `requirements` FR 표·§5 마일스톤 매핑이 seed(FR-N↔M-N 1:1)와 어긋나 FR-4 유령행·§5 오매핑(M2→FR-3) → seed 1:1 모델 정합 + FR-4 제거. **C**: `screens-overview` §2 전이도·§5 인증표가 fence 밖이라 입력 안 한 `dashboard`(미존재 화면) 고착 → §1 실측과 자기모순·dangling 링크 → 예시 배너 + 화면명 placeholder화. 데모 재생성 실측 검증, test-init-project 31 PASS. PR #168

## [1.34.0] — 2026-07-03

### Added
- **skill-body 게이트 결정적 회귀 인프라** — 유료 llm-smoke CI(secret 미등록 도먼트)에 의존하지 않고 recurring 결함 클래스(teeth in body, 강제 인프라 소실)의 **구조적 절반**을 무료·결정적으로 봉쇄. ① `validate-structure.sh` 신규 검사 `contract_consistency`(#15): cross-skill `BATCH-*-DONE` halt signal 의 방출(skill)↔감시(orchestrator) 정합 + suffix 일치 검사 — `<BATCH_ID>`↔`<FID>` drift·고아 signal 을 LLM 없이 CI 차단. ② `scripts/tests/test-gate-presence.sh`(9 assertion, run-all 자동편입): skill-body HARD GATE 문구 소실 회귀 — foundation 3-지점 계약(verify 생산 게이트·decomposing 소비 게이트·planning 강제 cross-ref)·경로 정합·BATCH 5신호 방출측. red-green 검증. PR #167

### Fixed
- **lifecycle 단계별 실측 결함 7건** — 신규 프로젝트 lifecycle 6단계 검증에서 발견·수정. **brainstorming**: Q0 라우팅↔자가점검 고정참조 역설(유료고객 경로가 항상 반려)·한글 slug `tr -cd` 전삭제→`scripts/slug.sh`(국립국어원 로마자) 교체. **init-project**: `api-spec-consumer.md` 가 배열 밖이라 git add 누락(고아화)→`git add .specops/memory`·constitution skip placeholder 누출 가드(T1.b 회귀). **start-foundation**: `foundation-manifest.md` 생산이 산문 지시뿐이라(강제 evaluator 부재) 후속 `/start` 재사용 게이트가 침묵 no-op 되던 구조 결함 → `verifying-evidence-ko` HARD GATE 신설(Mode1 태스크누락·Mode2 파일미작성 동시 차단). **start-all**: batch-level halt signal suffix drift(`<BATCH_ID>`↔`<FID>`) 정합. **release**: 문서가 실제 자동 push+GitHub Release 동작을 오도하던 것 정합. **specifying-ko**: Q5+ 명확화 위임을 spec.md §8 구체 기재로 명시(clarifying 경량분기 오판 차단). PR #165·#166

## [1.33.0] — 2026-07-03

### Added
- **LLM chain 저비용 CI (A층+B층)** — `.github/workflows/llm-smoke.yml` 주 1회 cron + workflow_dispatch 로 신호감지 대표 6 fixture smoke (~$3/회, `ANTHROPIC_API_KEY` secret 부재 시 graceful skip, 실패 시 issue 자동 통보 + FAIL 요약·redaction). `run-evals.sh` 완주 스탬프(`.specops-cache/llm-eval-last-run`, `LLM_EVAL_STAMP_DIR` 테스트 격리) + `release.sh` pre-flight staleness soft 경고(7일). red-green T8.a~d·T18.a~c. C층(월간 e2e cron)은 설계 기록만 — 사용자 후속 결정. FID `20260702-llm-smoke-ci`
- **chain 단일 source + 정합 게이트** — `hooks/chain.yaml` 이 lifecycle primary edge 의 Source of Truth 로 신설. `validate-structure.sh` 신규 검사 `chain_consistency`(#14) 가 21개 SKILL.md `## 다음 skill` 코드블록·메타 skill 화살표 목록과의 drift 를 양방향 적발 (edge 좌표 명시 FAIL). #150~153 전파 누락 4회 재발 클래스 차단. red-green T14.a~f (drift 4방향 + pyyaml SKIP + yaml 파손). FID `20260702-chain-single-source`

### Changed
- **critic-ask advisor 백엔드에 claude 최우선 추가** — `critic-ask.sh` provider 감지에 `claude` CLI 를 최우선(CRITIC_BIN 다음)으로 배선. 모델은 `fable` 우선·`opus` fallback(`--fallback-model`, `CRITIC_CLAUDE_MODEL`/`CRITIC_CLAUDE_FALLBACK` override). 기존 ollama 기본 모델(`qwen2.5:7b`) 불일치로 advisor fallback 이 사실상 죽어있던 문제 해소 — claude code 사용자는 claude CLI 를 항상 보유하므로 advisory critic 이 실동작. red-green T-claude 1~3.
- **하드코딩 목록 → frontmatter marker 역방향 스캔** — `validate-structure.sh` agent_tools 가 reviewer 3종 리터럴에서 `role: evaluator` marker 스캔으로 전환 (red/blue/auditor 편입 — 6종, `*reviewer*` 미마킹 2차 방어 + 마킹 0건 공회전 방지). `test-skill-conventions.sh` T9 가 discipline 3종 리터럴에서 `discipline: true` marker 스캔 + 하한 3 으로 전환. 신규 evaluator/discipline 항목은 marker 만 달면 자동 검사 편입 (T9 completeness Known-Limited 해소). red-green T15.a~d·T9.r/s. FID `20260702-marker-reverse-scan`

## [1.32.3] — 2026-07-02

### Changed
- **Superpowers 코멘트성 언급 제거 (21파일 29건)** — skill 본문 산문·`## 참조` upstream 링크 라인·footer stamp·메타 skill description 괄호·템플릿 예시 경로(`docs/superpowers/...`)·템플릿 HTML 주석에서 Superpowers 표기 제거. **인프라 데이터는 유지**: frontmatter `reference_upstream:`(validate-structure·diff-upstream 소비), `docs/upstream-drift-log.md` 자동 생성 기록, CHANGELOG 과거 릴리즈 노트, `.specops-cache/upstream/`. 기능 무변경 — 사용 중 노출 표면만 정리.

## [1.32.2] — 2026-07-02

### Fixed
- **2026-07-02 전체 감사 잔여 LOW 5건 일괄 처리** — ① `test-shellcheck-lint.sh` 신설: CI 전용이던 `shellcheck -S error` 게이트의 로컬 run-all parity(미설치 시 graceful SKIP) — 로컬 green 후 push 에서 최초 발각되던 비대칭 해소. ② `_replace_token` 토큰(LHS) BRE 메타문자 escape — `.` any-char 오매치·`*[]` 미매치·`|` 구분자 파손 차단, `test-init-lib-token.sh` 5케이스 red-green. ③ `diff-upstream.sh` trap EXIT — 중단 시 임시파일 6종 잔류 방지. ④ used_by frontmatter 정합 2건 — `systematic-debugging-ko` 에 security-review-ko FAIL 분기 추가, `advisor-ko` 를 실배선 기준(ambient + planning-ko 실호출)으로 정확화. ⑤ 훅 표기 정밀화 — CLAUDE.md·README "훅 4종" → 거버넌스 4종 + Notification 보조 1종.
- **Stop 훅 `.specops` symlink 가드 대칭화 (#144 잔여)** — `log_friction` 계열에만 적용됐던 write-through path-escape 가드를 같은 Stop 계층의 나머지 `.specops` writer 2곳에 전파. `freecomment-capture.sh`: `.specops` 디렉토리·`pending-capture.jsonl` 파일 symlink 시 append 거부(safe_exit). `ensure-session-progress.sh`: `.specops` 디렉토리·`session-progress.md` dangling symlink 시 write 거부(조용히 exit 0). 악성 repo 가 symlink 를 심어 repo 밖 파일에 쓰게 만드는 벡터 차단 — 한 세션 안에서 log_friction 은 거부하는데 다른 writer 는 관통하던 자기모순 해소. 회귀 테스트 4케이스(T5.a/T5.b, T1.f/T1.g) red-green.
- **`validate-context.sh` §3 fence 상태 추적 결함** — 닫는 ``` 가 `(bash|sh)?` 빈 매치로 여는 패턴에 걸려 `in_b=0` 규칙이 죽은 코드였음. 빈 코드블록 뒤 산문이 테스트 명령으로 오인돼 실제 명령 없는 dispatch context 를 거짓 PASS 하는 검증기 soundness 결함. fence 상태 토글 + bash/sh/bare 여는 fence 만 캡처로 교체. 회귀 테스트 T5.a(산문 누출 차단)·T5.b(비-bash fence 미인식) red-green.

### Docs
- **2026-07-02 전체 감사 문서 drift 4건 정정** — README 커맨드 자산 트리에 `promote.md`·`status.md` 누락 2건 추가(헤더 19건 ↔ 열거 17건 불일치 해소). README 템플릿 분해 산문에 v1.32 신설 `api-spec-consumer`(init-project 12→13)·`freework`(Lifecycle 18→19) 반영(합계 32 유지). CONTRIBUTING 테스트 카운트 stale 정정 — 구조검증 `12/12 OK`→`전 항목 ✅`(실제 14항목·N/N 총계 미출력), 거버넌스 `PASS=72`→`FAIL=0` 표기(실측 74, brittle 고정숫자 회피). `docs/upstream-drift-log.md` validate-structure 경로 `scripts/`→`scripts/_internal/` 정정.

## [1.32.1] — 2026-07-02

### Fixed
- **`emit-context.sh` §6에서 `api-spec-consumer.md` 제거** — 소비자 IF는 init-time·KIND-gated 1회 생성 문서(per-feature 아님). §6 per-feature 계약 목록에 포함 시 specifying-ko Step 5.6·verifying 역방향 안전망과 3-way 불일치 발생. `frontend-architecture.md`와 동일 패턴으로 §6 제외.

## [1.32.0] — 2026-07-01

### Added
- **`/init-project` Phase 8g — 소비자 IF 템플릿(`api-spec-consumer.md`) 신설** — KIND 1(UI)·5(Mobile)에서 외부 API 소비 계약 문서를 y/N 프롬프트로 조건부 생성. `templates/api-spec-consumer.md` 신설(소비 서비스 목록·의존 엔드포인트·실패 처리 전략). `specifying-ko` 부재 가드에 소비자 분기 명시. `templates/CLAUDE.md`·`frontend-architecture.md` 인덱스 업데이트. `test-init-project.sh` T1.a 수정 + T15.a(consumer=y 케이스) 추가.

### Changed
- **commands frontmatter 스키마 위생** — `log.md`·`release.md`·`statusline-install.md` 3개 파일에 누락 필드 추가. `log.md`: `triggers·mode·specops_version·specops_layer·reference_upstream·footer` 신설. `release.md`: `specops_layer·reference_upstream` 추가. `statusline-install.md`: skills 포맷(`layer·used_by`) → commands 포맷(`triggers·mode·specops_layer`) 변환·footer 추가. 런타임 무영향.

## [1.31.0] — 2026-07-01

### Fixed
- **`_verify_passed_in_progress` 타임스탬프 비교 전환 — prepend 불변식 의존 제거** — 기존 줄 번호(`vline < cline`) 비교가 session-progress 작성자가 내림차순(prepend) 대신 오름차순으로 기록할 경우 false-allow를 유발하는 구조적 취약점. `YYYY-MM-DD HH:MM` 전체 타임스탬프 추출 + `sort -r | head -1`(max) 비교로 교체. 날짜경계(23:59→00:00) 자동 처리. 동률(same-minute) → 안전측 `return 2`(deny). 행 선두 앵커(`^- YYYY-MM-DD HH:MM /command`)로 memo 자유텍스트 날짜 오염 차단. `test-verify-progress.sh` T-H2a/T-H2b/T-H2c 3케이스 추가(줄순서↔타임스탬프 불일치 시 타임스탬프 기준 판정 검증). 기존 T1~T13 전체 회귀 없음.

## [1.30.0] — 2026-07-01

### Fixed
- **`diff-upstream.sh` plugin_root 경로 계산 오류** — `scripts/_internal/` 하위에서 실행 시 `dirname` 1회 적용으로 `scripts/`를 repo root로 오인하던 버그. `cd "$script_dir/../.."` 2단계 상위로 수정. struct=0→21, manual=0→26 정상 산출. 테스트 sandbox 경로도 동일하게 수정 (T2~T7 PASS). (#155)

### Added
- **`writing-skills` 방법론 흡수 — failure-first + rationalization table 3 인프라 동시 전파** — superpowers upstream drift 점검에서 rationalization 섹션 대거 추가 확인(실증 근거). 신규 skill 추가 없이 기존 3 인프라에 teeth 동시 전파(aspirational-without-enforcement 방지): `CONTRIBUTING.md` Skill 작성 방법론 신설, `templates/SKILL.md` 합리화 차단표 섹션 양식 추가, `test-skill-conventions.sh` T7/T8 형식 게이트. `using-git-worktrees-ko` 적색 플래그 누락 항목 보강(EnterWorktree native tool 우선, upstream v5.1.0). (#156)

### Refactored
- **discipline-class skill 합리화 차단표 헤딩 통일 + T9 gate** — `## 흔한 합리화`(systematic-debugging-ko, tdd-ko), `## 합리화 방지`(verifying-evidence-ko) → `## 합리화 차단표` 통일. `test-skill-conventions.sh` T9: 3종 discipline-class skill 합리화 차단표 섹션 존재 강제 게이트. T1~T9 10개 체계 완성. (#157)

## [1.29.0] — 2026-06-30

### Added
- **인터페이스 design-first 대칭 — `specifying-ko` Step 5.6 신설** — 화면(Step 5.5)처럼 인터페이스(API 엔드포인트·DB 스키마)도 구현 전 `api-spec.md`·`data-model.md` 에 **먼저 설계 반영**한다. 그간 화면만 design-first(Step 5.5)이고 인터페이스는 설계 단계 없이 구현→방치되던 비대칭 해소. 보조로 `verifying-evidence-ko` 에 **역방향 안전망**("memory 설계 동기화 점검") 추가 — 구현(`git diff`)을 inspect-first 로 읽어 memory 문서와 괴리 감지 시 evidence.md 에 권고 기록(자동수정 금지, chain 비차단). 산출물이 init 골격 후 stale 되던 lifecycle 단절 해소. (ecc inspect-first 메커니즘 차용, SI design-first 철학 유지) (#150)
- **self-config 적대감사 번들 범위 확대** — `self-config-collect.sh` 가 `agents/*.md`·`scripts/_internal/**` 표면까지 흡수(44→90 표면). 1차 감사 미수집 4종(kill-switch·agents·statusline·init-project) 수집. TDD 회귀 `T1.e2~e6`. (#141)

### Fixed
- **3 진입점 검증 잔여 7건** — #153 후속 마무리(MED 2 + LOW 5): ① CLAUDE.md 템플릿 `frontend-architecture`·`screens-overview` 가 `(UI/풀스택만)` → 실제 게이트 Mobile(5) 포함 정정 `(UI/풀스택/모바일)` ② `decomposing-ko` 마이그레이션 트리거를 `data-model.md` 존재 → **plan.md DDL 표면**으로 확장(미부트스트랩 `/start-auto` DB 기능서 reverse/test 없이 진행되던 구멍 차단) ③ data-model.md 헤더 `## N` → `## §N`(api-spec·인용처 §N 정합) ④ init Phase 8e/8f `_should_skip` 선검사(resume 시 불필요 프롬프트 회피, 타 phase 와 정합) ⑤ foundation 흐름도 노드에 Step 5.6 명시 ⑥ 유지보수 분기에 스키마/API 수정 시 Step 5.6 + AC-R-2 연계 명시 ⑦ `maintain.md` 사용 예에 analyzing-ko 단계 삽입(stale 정정). (#154)

- **3 진입점 검증 — design-first 인프라 전파 결손 4건** — init/start/maintain chain 병렬 검증으로 발견: #150~152 가 skill body 만 강화하고 의존 인프라(템플릿·자동생성기·게이트)에 전파를 누락해 teeth 가 aspirational 이던 것 실배선: ① **trivial 게이트 데이터손실 우회** — `analyzing-ko` trivial 판정(≤5줄)이 파괴적 스키마(`ALTER DROP`)를 우회해 §2 롤백분석·AC-R 면제하던 것에 **스키마 override**(스키마 변경 시 라인수 무관 비trivial) ② **impact-analysis 템플릿 전파** — expand-contract·코드롤백≠데이터롤백·data-down 보존 필드를 §2 템플릿에 영속(고아 inline 해소) ③ **회귀 AC-R-2** — 데이터 보존·역가역성(up→down→up 멱등) 회귀 AC 스텁(스키마 변경·override 시 강제) ④ **implementing 계약 dispatch 실배선** — `emit-context.sh` 가 설계 산출물 존재 시 dispatch 컨텍스트 **§6 설계 계약**에 경로 자동 emit(부재 시 graceful), `implementing-ko` 후진 teeth 가 병렬/자동 경로서 실제 도달(TDD `T1.f/g`). (#153)

- **DB 테이블 설계→구현 lifecycle 결손 3건** — 독립 분석으로 발견: 설계(data-model design-first)는 #150/#151 로 됐으나 "설계 이후"가 비어 있던 것 보강. ① **마이그레이션 흐름 부재** — `decomposing-ko` 에 마이그레이션 **forward+reverse 태스크 쌍** 분해 패턴 추가(up/down·멱등 테스트·DDL 도구 규약, 단순 "비가역 격리"에서 격상) ② **DB 전문 리뷰 부재** — `code-reviewer-ko`(Phase C) 에 조건부 **DB 스키마 관점**(인덱스·FK ON DELETE·N+1·정규화·data-model↔DDL 정합) 추가 ③ **데이터 손실 롤백** — `analyzing-ko` §2 가 스키마 변경 롤백을 `git revert`(코드만)로 답하던 것을 **코드 롤백 vs 데이터 마이그레이션 down 구분** + expand-contract 안전 패턴 명시(`ALTER DROP` 데이터 복원 불가 경고). (#152)

- **인터페이스 design-first 배선 결함 7건 (#150 follow-up)** — 적대 검토(Generator↔Evaluator 분리)로 #150 의 미완성 배선 발견·수정: ① **verify 안전망 무력화** — `/implement` 태스크별 커밋으로 working-tree 클린 → bare `git diff` 빈출력 → 항상 통과하던 것을 `git diff base...HEAD`(R-2 동일 패턴)로 수정 ② **foundation 분기 Step 5.6 미배선** — DB 스키마 본진이 design-first 미적용이던 것 배선 + §2 DAG/data-model 역할 경계 명시 ③ **design-first 강제력** — `implementing-ko` 에 "설계 계약 준수"(screens·api-spec·data-model 화면·인터페이스 대칭) 후진 teeth 추가 ④ **§auto·흐름도가 Step 5.6 우회** — §auto 화면 블록 Step 6 직행 수정 + 프로세스 흐름도에 5.6 노드 추가 ⑤ **§auto 부재 가드** — 무인 마스터 문서 임의생성 금지 + batch append-only ⑥⑦ 추출 기준·섹션 표현 통일. (#151)

- **self-config 감사 잔여 backlog 처리** — 2026-06-30 `/security-scan --self-config` 실전 감사(등급 D) 후속 fix 묶음:
  - SessionStart rehydrate 신뢰경계 펜스 — untrusted-repo `session-progress.md` 자동주입을 `<untrusted-repo-content>` 태그로 래핑(R5). (#142)
  - `log_friction_sev` 디렉토리 symlink 가드 대칭화 + verify-stamp 면제 불변식(vp=1 전용·vp=2 불가침) characterization 잠금(R6·N1). (#143)
  - `friction-log.jsonl` **파일** 자체 symlink append 가드 — 디렉토리만 검사하던 사각 보강, 양 함수 `[ ! -L ]` 대칭. (#144)
  - untrusted-repo 출력 위생 — statusline `step`/`status` 제어문자 strip(ANSI escape injection 차단) + `phases-artifacts.sh` raw sed→`_replace_token`(N5·N6). (#145)
  - posttool R-3 trigger 패턴 `rules.jsonl` 단일소스화(하드코딩 drift 제거) + 감사 에이전트 Bash 행동계약 명문화·auditor description 정직 정정(R8·N2·N3). (#146)

## [1.28.0] — 2026-06-29

### Added
- **gbrain confidence scoring — ecc instinct 흡수** — `gbrain-append --confidence low|medium|high` enum 옵션으로 learnings 레코드에 조건부 `confidence` 필드(미지정 시 생략 — 기존 ~120 레코드 graceful). `gbrain-recall` score 동점 시 confidence 가중(high=3/medium=2/low=1/미지정=0) tiebreak + 표시, `gbrain-ko` 조회 출력 렌더. confidence 는 **표시·정렬 보조만** — `/evolve` skill 자동생성·임계 자동승격은 흡수 금지(메타플러그인 무결성). 회귀: recall 탭 평탄화(jq `$txt|gsub`) + 테스트 mktemp 가드. (#139, #140)
- **`SPECOPS_GOVERNANCE_PROFILE` 프리셋 (minimal/standard/strict) — ecc #4 흡수** — `is-hook-enabled.sh` 에 ENV 프리셋 분기. minimal(pretool+session-start)·standard(4 훅)·strict(6 훅). **minimal 도 R-1/R-2 hard-block 유지**(거버넌스 해자 보존). pyyaml 독립 bash case. (#137)

### Changed
- **advisor-ko 이종 백엔드 자동 fallback 확대 — omc #2 경량 흡수** — `critic-ask` 연결지점 2→5곳 + 미연결 시 자동 fallback 트리거. advisor 미연결 환경에서도 graceful. (#136)

### Fixed
- **R-1/R-2 verify 면제 방어 보강** — R-1 면제가 verifying-evidence-ko skill transcript 패턴에 강결합돼 직접 verify(skill 우회) 시 false-block 하던 결함 수정. `run-verification.sh` 의 `RUN-VERIFICATION-RESULT` evidence stamp 를 보조 면제 신호로 추가 + `_verify_passed_in_progress` **3-state**(0 유효/1 inconclusive/2 affirmative-stale). stamp 면제는 vp=1 만, vp=2(stale)는 stamp 무시 차단(거짓면제 0, T39 보존). (#138)

## [1.27.0] — 2026-06-29

### Added
- **`/security-scan --self-config` 모드 — ecc AgentShield 흡수** — 플러그인 **자기 설정**(`hooks/*.sh`·`skills/*/SKILL.md`·`rules.jsonl`·`plugin.json`·`settings`)을 red/blue/auditor 3 서브에이전트 적대추론으로 on-demand 보안감사. `collect → red → blue → auditor` CHAIN, risk 등급(A~F). 그간 수동 심층감사(PR #129/#130/#134)로 메우던 사각지대 자동화. (#135)
- **`scripts/self-config-collect.sh`** — 자기 설정 표면 read-only 번들. 공백 경로 안전(`-print0` + process substitution), `.claude-plugin/plugin.json` 마커 부재 시 거부(임의 경로 차단).
- **`agents/red-team-ko`·`blue-team-ko`·`auditor-ko`** — 적대감사 3종. `tools: Read/Grep/Glob/Bash` read-only 불변식(Write/Edit 미보유 → 거버넌스 훅 충돌 0). 회귀 테스트 `test-self-config-collect`(공백경로 포함)·`test-self-config-agents`.

### Design
- ecc AgentShield 의 red/blue/auditor 적대 파이프라인은 specops 의 **Generator↔Evaluator 분리 철학과 동형**이라 자연 흡수. on-demand 전용(토큰 비용 관리), 기존 `/security-scan` SAST/DAST 무변경.

## [1.26.5] — 2026-06-27

### Security
- **`.specops` symlink path-escape 차단** — `.specops` 가 symlink 면 `mkdir -p .specops` 가 OS 따라 외부 dir 타겟에 friction-log·session-progress 를 write-through(악성 repo clone 시 정보 누출·파일 clobber)하던 표면 차단. `governance-lib` 의 `log_friction`·`log_friction_sev` + `session-progress-append.sh` 진입에 symlink 거부 가드(`_specops_dir_safe`). 정상 dir 영향 0. 회귀 테스트 `test-lib` T-symlink 추가. (심층감사 보안 M-A)
- **ui-ux-pro-max 의존 상한 핀** — `>=2.0.0` → `>=2.0.0 <3.0.0`. cross-marketplace hard dependency 의 major breaking 릴리즈 자동 신뢰 표면 축소(공급망). (심층감사 보안 S-1)

### Changed
- **테스트 헬퍼 공통화 (DRY) — `scripts/tests/harness.sh` 신설** — `ok`/`fail`/`nope`/`run` 헬퍼를 26+파일에 인라인 재정의하던 중복(변종 4종 + 출력포맷 드리프트 `PASS:`/`FAIL -`/`FAIL —`)을 단일 하네스로 통합. `ok/fail/nope/run/finish` 표준 시그니처 + 통일 출력. ok/nope/fail/run 클러스터 **28파일**을 `source` 로 교체. check/ck 클러스터(소문자 `pass/fail` 카운터·grep 매칭 시그니처)는 별도 체계라 범위 외. 회귀: run-all 79/79. (심층감사 중복/DRY)

## [1.26.4] — 2026-06-27

### Added
- **`/status [<FID>]` 슬래시 신설 — 재개 조회 수단** — 오펀이던 `show-fid-status.sh`(Lifecycle 단계·아티팩트 ✅/❌ 현황)를 슬래시로 연결. 인자 없으면 session-progress 최신 FID 자동. 메타skill "미완 lifecycle 재개 통보"(자동 1줄)와 짝을 이루는 능동 상세 조회. (심층감사 UX backlog)

### Changed
- **start 계열 5종 description 직교 태그** — 동일 prefix 로 슬래시 메뉴 구분이 약하던 것에 `[단일·대화형]`·`[단일·무인]`·`[전체·대화형]`·`[전체·무인]`·`[공통부·대화형]` 선두 태그 부여. (심층감사 UX M2)
- **FID 슬러그 생성 가드** — `specifying-ko` Step 0 에 슬러그 규칙 명시(소문자 kebab·최대 40자·빈값 시 `feature-<HHMM>` fallback·trailing dash 금지) + `git-branch-create.sh` 2차 방어(빈 슬러그 `YYYYMMDD-`·60자 초과 거부). LLM 생성 FID 가 기형/과길이 되던 표면 차단. (심층감사 UX M1)

## [1.26.3] — 2026-06-27

### Fixed
- **session-start `escape_for_json` 잔여 C0 제어문자 누출 — 거버넌스 침묵 무력화 차단** — `\t\n\r` 외 제어문자(BS·ESC·NUL 등)를 미escape 해 raw 제어문자가 `additionalContext` JSON 을 invalid 화 → Claude Code 가 메타skill+거버넌스 스캐폴드를 통째 drop 하던 침묵 무력화. `tr -d` 로 잔여 C0 제거. (PR #130, 심층감사 M-B — gbrain escape fix 와 동일 클래스 잔존분)
- **`git-branch-create.sh` 기존 브랜치 무경고 재사용 — 가시화** — `-b` 실패 시 기존 브랜치로 침묵 전환하던 것을 WARN 출력. 같은날 동일 기능명 재실행 시 산출물 덮어쓰기 경고. (PR #130, 심층감사 H1)
- **`security-scan.sh` self-check only 미표기 — full SAST 오인 방지** — semgrep·gitleaks 미설치 시 self-check 만 실행됐는데 `crit=0` 만 출력해 전체 SAST 통과로 오인되던 것에 `(self-check only — semgrep·gitleaks 미설치)` 병기. (PR #130, 심층감사 M6)
- **거버넌스 훅 한/영 메시지 불일치** — posttool·stop 의 영어 `stdin JSON parse failed` → 한국어 통일(pretool 과 정합). (PR #130, 심층감사 M5)

### Added
- **미완 lifecycle 재개 통보 규칙** — `using-specops-ko` 메타skill 에 SessionStart rehydrate 데이터를 사용자에게 통보하는 규칙 신설. 미완 FID 의 최신 단계·다음 단계를 점검해, 새 신호 시 1줄 참고·신호 없을 시 능동 재개 제안(완료 FID 는 침묵). rehydrate 데이터는 있으나 통보 규칙이 없던 가시화 공백 해소. (심층감사 H2 — 5원칙 4 주권: 새 신호 우선)

## [1.26.2] — 2026-06-27

### Fixed
- **pretool 거버넌스 R-1/R-2 관할 한정 — `.specops` 부재 repo 월권 차단 제거** — 플러그인 훅이 전역 발화하므로 specops 미사용 repo(`.specops/` 디렉토리 부재)의 `git commit`·`gh pr create` 까지 verify 누락으로 하드차단하던 결함(5원칙 4 주권 위반). `[ -d .specops ] || allow` 가드 추가 — lifecycle 진행 중(`.specops` 존재) repo 는 그대로 강제(보호 손실 0). `test-pretool` deny sandbox 3종 `.specops` 보정 + T40 신규(red-green). (PR #129, 재감사 M2)
- **`using-specops-ko` 유지보수 분기 ASCII 자기모순 정정** — 진입 다이어그램이 `analyzing-ko ★HARD GATE` 선행을 건너뛰고 `specifying-ko 직행`으로 표기(Phase A 잔재)해 권위 테이블과 모순. `analyzing-ko 먼저 → specifying-ko` 로 정합화. (PR #129, 재감사 M1)
- **`session-progress-append.sh` partial clobber 차단** — `awk > TMP` 후 `mv` 무조건 실행 → `&&` 결합(awk 중간실패 시 손상 TMP 가 TARGET 덮어쓰기 차단, 2곳). (PR #129)
- **`freework-resolve-fid.sh` FID 포맷 가드** — 진입부 정규식 검증 추가로 메타문자 유입 시 awk 동적정규식 오판정·오귀속 방지(타 스크립트와 일관). (PR #129)

### Changed
- **문서 정합 2건** — `using-specops-ko` 참조 섹션 폐기된 `engine/*·harness/*` 중첩구조 표기 → 플랫 구조 갱신, `analyzing-ko` `used_by` 에 `/promote` 누락 추가. (PR #129)

## [1.26.1] — 2026-06-26

### Changed
- **`init-project.sh` 책임 분할 (705→78줄) — deep module 리팩터링** — improve-arch shallow 판정(705줄·37함수·비율18)을 받아 공용 헬퍼 + phase 그룹을 `scripts/_internal/init-project/{lib,phases-early,phases-design,phases-artifacts}.sh` 4개 모듈로 분리. 본체는 전역 선언 + `_DIR`(BASH_SOURCE 기준) 4 source + `main()` + source 가드만 보유. 순수 이동 — 36/36 함수 byte-identical, 함수 총합 37 불변, 동작·CLI 인터페이스 무변경. (PR #127)
- **`init-project.sh` PLUGIN 경로 `$0` → `${BASH_SOURCE[0]}` 통일** — split 도입한 `_DIR` 와 동일 기준으로 통일해 source 컨텍스트에서도 PLUGIN(템플릿 복사 베이스) 정확 해석. 직접 실행 시 `$0==BASH_SOURCE[0]` 라 동작 동일. (PR #128)

### Added (내부 — 회귀 검사)
- `test-init-project-split.sh` 신설 — 임의 cwd source 시 헬퍼+phase 함수 로드 + source 가드(main 미자동실행) 검증 (AC-R-2). (PR #127)

## [1.26.0] — 2026-06-26

### Fixed
- **`gbrain-append.sh` 제어문자 escape — 인사이트 영구 유실 차단** — `json_esc`(수동 `\`·`"` 2종 치환)가 개행·탭(U+0000~U+001F)을 미처리해 `learnings.jsonl` 에 무효 JSON 줄 + recall 유실되던 결함. insight/fid 도 tags 와 동일하게 `jq -cn --arg/--argjson` 전체 객체 생성으로 전환. (PR #123, 감사 H1)
- **R-1 commit trigger over-match — `git commit-tree` 오차단 해소** — trigger `commit\b` → `commit($|[^-[:alnum:]])`. `git commit`/`-m`/`;` 차단은 유지하며 plumbing(`commit-tree`)만 허용. `rules.jsonl`+pretool prefilter 동시 변경(H-1 single-source 정합 유지). (PR #126, 감사 low L2)
- **`session-progress-append.sh` mktemp 무방어** — 2곳 `|| exit 1` 추가(침묵 실패→false success 차단). (PR #126, low L3)

### Changed
- **verify-lookback 줄순서 불변식 정합 (거버넌스 우회 방지)** — `_verify_passed_in_progress` 의 `vline<cline` 비교가 "session-progress 줄 최신=상단(prepend)" 에 보안 의존하나 `context-resets-ko` 예시가 오름차순으로 모순 → writer 가 따라 쓰면 R-1/R-2 false-allow. 문서 정합(`context-resets-ko`·`structured-artifacts-ko`)+불변식 주석 명문화. (PR #123, 감사 H2)
- **metadata drift 정정** — security-review-ko chain 서술 누락 4곳, `used_by` full-prefix→short name 16개, `implementing-ko` 진입 표기 planning→decomposing. (PR #124, 감사 M1~M3)
- **agent tools 하드강제 + file-based 정합** — reviewer 3개 frontmatter `tools:`(Read/Grep/Glob/Bash, Write/Edit 박탈)로 Generator-Evaluator 분리 구조 강제. `implementing-ko` payload 잔재→path-only 정정, Phase B→C PASS 보고서 경로 규약 신설. (PR #125, 감사 M5~M7)
- **dead-ref 정정** — `verdict-board.sh` README 등재(발견성), `log-subagent-calls.sh` dangling 참조 "미구현" 명확화. (PR #126, 감사 M4)
- R-3 하드코딩 패턴 ↔ `rules.jsonl` 동기 NOTE(dead config drift 경고), `validate-structure` 헤더주석 수치 제거(드리프트 방지). (PR #126, low L1·L4)

### Added (내부 — 회귀 검사)
- 구조 검증 회귀 검사 3종 신설: `used_by_fmt`(used_by short name 규약), `agent_tools`(reviewer read-only 하드강제), `test-pretool` T15b(commit-tree allow). (PR #124·#125·#126)

## [1.25.0] — 2026-06-26

### Fixed
- **거버넌스 R-1/R-2 verify lookback false-block 수정** — 긴 lifecycle(도구 20+ 호출) 후 commit/PR 시 verify Skill 이 transcript `negative_lookback=20` 밖으로 밀려 false-block 되던 결함 해소. `_verify_passed_in_progress(fid)` 헬퍼가 `session-progress.md` 의 `/verify PASS` 를 윈도우 밖 보조 면제 신호로 사용(R-1/R-2 공용). `SPECOPS_GOVERNANCE_BYPASS=1` inline prefix 면제도 추가(메시지 내 토큰 언급은 미면제). (PR #118, FID `20260625-governance-lookback-fix`)
- **docs-only 면제 rename 우회 차단** — `is_docs_only_change` 의 git diff 호출에 `--no-renames` 추가. 코드파일을 `.md` 로 rename(`tool.sh`→`tool.md`)해 docs-only 오인 면제되던 표면 차단(rename→delete+add 분해로 원본 노출). (PR #122, FID `20260626-r2-docs-edge`)

### Added
- **`/promote` baseline 시드 구현 완성 (G5)** — `analyzing-ko` Step 0 promote-fid 분기 선언이 Step 1 시드 로직에 미연결되던 갭 해소. `freework.md` files 1차 → `git diff`/`log` 보조 → 둘다 빈손 시 한계고백(빈 §1 금지). (PR #121, FID `20260626-diagnostic-residual`)

### Changed (내부 — 테스트·문서)
- 거버넌스 통합 wiring 회귀 픽스처 T38/T39 + sandbox `mktemp -d || exit 1` guard 5곳. (PR #119)
- `rules.jsonl` trigger ≡ pretool L31 prefilter single-source 정합성 테스트 T-H1(H-1). docs 면제 rename 회귀 T-docs.j~m. (PR #121·#122)
- WON'T-FIX 한계 문서화: verify staleness(self-report 2차방어), F-3 wrapper 우회(honest-mistake 경로 부재), G1 freecomment 멱등(truncate 자동화 본질불가). e2e-test 수동전용 CLAUDE.md 명시. (PR #120·#121)

## [1.24.0] — 2026-06-25

### Added
- **`/promote` 승격 커맨드 — 자유작업 mini-FID → lifecycle in-place 승격** — 자유작업이 만든 mini-FID(`freework.md` 마커만 있는 경량 트랙)를 lifecycle full 트리로 in-place 승격한다. `freework.md` 를 시드로 `spec.md`+AC 를 역작성하고 이미 된 변경을 보존(회귀 테스트 보강)해, 자유작업에서 시작한 일을 정식 lifecycle(specify→…→PR)로 끊김 없이 이어받는다. v1.23.0(PR #116)이 남긴 "자유작업→lifecycle 승격" 갭을 메움.
- 진입 검증을 `scripts/promote-validate.sh` 헬퍼로 추출(`OK`|`REJECT:<사유>` 7케이스 — bash 단위테스트 가능). `commands/promote.md` 가 거부 5케이스를 표준 문구로 매핑 + args 합성(`entry:maintain`+`promote-fid` 신호) → `analyzing-ko` 진입. `analyzing-ko` Step 0 promote-fid 분기가 mini-FID 를 in-place 재사용(새 FID 생성 skip, 기존 `/maintain` 동작 무손상). FID 포맷 검증(`[0-9]{8}-[a-z0-9-]+`)으로 경로 traversal(`fid=.`·`../x`) 차단. (PR #117, FID `20260625-promote-command`)

## [1.23.0] — 2026-06-25

### Added
- **자유작업 lifecycle 완전 통합 (freecomment mini-lifecycle 편입)** — 자유작업(freecomment-capture)에 FID를 부여해 `.specops/<FID>/` 트리·session-progress·learnings(`--fid`)에 양방향 추적 편입. Stop훅 `detect_fid()`로 활성 FID 후보를 pending stub `fid` 필드에 기록 → 다음 턴 메타skill이 `scripts/freework-resolve-fid.sh`(종결마커 판정)로 **귀속(ATTACH)** / **신규(NEW mini-FID)** 분기. mini-FID는 경량 `templates/freework.md` 마커(spec.md 없는 트랙)로 편입.
- **종결마커 false-positive 방어** — 종결 판정 정규식을 command 슬래시 앵커(`/lifecycle DONE`)+`PR #N 생성` 인접으로 협소화해 진행중 줄("PR #999 참조")의 오귀속 차단. `test-resolve-fid.sh` 7케이스 회귀 고정. (PR #116, FID `20260625-freecomment-lifecycle-integ`)

## [1.22.1] — 2026-06-25

### Fixed
- **문서 drift 정정 (commands 16→17 + `/log` 누락)** — v1.22.0 `/log` 추가 시 사람 읽는 문서가 갱신 누락. README(슬래시 진입로 `(16건)`→`(17건)` + `log.md` 항목 추가)·scripts/README(`commands=16`→`17`) 정합화. `file_counts` 게이트는 `.structure-baseline` JSON 단일소스 기준이라 검증엔 무영향이었음(사람 문서만 drift). `specifying-ko` frontmatter `reference_upstream` bullet 글자그대로 중복 첫 줄에 부연 추가(clarifying-ko lineage 표기 규약 정합). validate-structure 13/13 OK 실측.

## [1.22.0] — 2026-06-25

### Added
- **자유 코멘트 작업 자동 캡처** (FID 20260625-freecomment-capture, PR #113) — lifecycle 밖 자연어 코멘트로 처리한 작업(오류수정·질문·설계변경)을 specops 기억 산출물에 자동 기록. Stop 훅(`hooks/freecomment-capture.sh`)이 메인 transcript 직접 Edit/Write ∩ `git diff HEAD` 교차로 자유작업 감지(서브에이전트 `Task` 경유 lifecycle 작업과 자동 구분) → `.specops/pending-capture.jsonl` stub(3유형 fix/question/design-change 키워드 분류). SessionStart 훅이 다음 세션에 `<freecomment-pending>` 안내 주입 → 메인 LLM 이 요약·`type` 재분류 → `.specops/freelog.md`(전용 영속 기록, session-progress 와 격리해 rehydrate 회귀 차단) + `learnings.jsonl` 기록 → pending 비움(멱등) → 1줄 보고. `/log` 수동 보강 커맨드(`commands/log.md`). 변경 0 세션 skip(노이즈 차단)·fail-open(세션 종료 무차단). 메타 skill 처리 규약 7단계 문서화. 회귀: `scripts/tests/freecomment/test-*.sh` 5스위트 10케이스.
- **requirements 자동 연결 강화** (FID 20260625-requirements-autolink, PR #114) — 자유작업 `design-change` 유형을 `requirements.md` FR 표에 **반자동(승인형)** 연결. `scripts/requirements-append-fr.sh` 신설(FR 채번 수치정렬 max+1·`|`→`\|` escape·개행 정규화·멱등(중복 desc skip)·atomic mv·FR 표 미발견 가드). 메타 skill 처리 규약: design-change 시 LLM 이 FR 초안 생성 → 사용자 `[y/n]` 승인 → 헬퍼 호출. **AC-6(자동변경 금지) 유지** — 오탐(단순수정→FR 표 오염)은 LLM 1차 판단 + 승인 게이트로 이중 차단. `requirements.md` 는 이전까지 읽기 전용(자동 쓰기 0)이었음. 재사용: `_replace_line_prefix`(init-project.sh) ENVIRON escape 패턴. 회귀: `test-requirements-append.sh` 6케이스(채번·NFR무손상·멱등·escape·FR10→11 수치정렬·부재).

### Fixed
- **freecomment test-capture CI(ubuntu) git ident 실패** (PR #113) — CI ubuntu runner 의 git user ident 미설정으로 테스트 격리 repo `git commit --allow-empty` 가 "Author identity unknown" 실패 → HEAD 없음 → hook `git diff HEAD` 빈 → 자유작업 미감지. macOS 로컬은 ident fallback 으로 가려졌던 환경 의존 버그. 격리 repo commit 3곳에 `-c user.email/-c user.name` 명시로 ident 자급.
- **Stop 훅 회귀 가드 + run-all 글롭** (PR #113) — `test-notify.sh` Stop 훅 개수 단언 `length==2→3`(freecomment-capture 추가 반영, 기존 2종 무손상 검증 유지), `run-all.sh` 글롭에 `freecomment/test-*.sh` 추가(릴리즈 게이트 연결).

## [1.21.3] — 2026-06-24

### Added
- **`release.sh` 원격 push + GitHub Release 자동 발행** (FID 20260623-release-gh-publish) — 기존 로컬 commit+tag 후 사용자가 수동 `git push`하던 마지막 단계를 자동화. release.sh가 commit·tag 완료 후 `origin` 존재 시 `git push` + `git push origin v<VER>` → `gh release create v<VER> --verify-tag --latest` 까지 수행. release 노트는 CHANGELOG `[<VER>]` 섹션 본문을 `awk` 추출 + compare 링크 append(`--notes-file`), 본문 부재 시 `--generate-notes` fallback. `--latest` 명시로 backfill 시 관측된 Latest 배지 오염 차단. **fail-safe**: `origin` 부재(테스트 임시 repo) → push/release skip(기존 테스트 무손상), `gh` 미설치 → release만 graceful skip(push는 보존)·수동 명령 안내. dry-run 안내에 7·8단계 추가. 회귀: test-release T14(bare origin + `gh` stub로 push·태그·`--verify-tag/--latest/--notes-file` 호출 검증, 실 GitHub 호출 0) + T15(origin 부재 skip + 로컬 태그 보존), PASS 18→24.

### Changed
- **문서 현행화** — 사용자 문서를 실제 구조·수치와 정합화. README(commands 16건 `statusline-install`·hooks 4종 PreToolUse/pretool·templates 30건 `critic-prompt-*`)·scripts/README(검증항목 6→12·suites 42→68·v1.21.2·경로 `_internal/`)·CONTRIBUTING(테스트 목표 12/12·PASS=72·PASS=24·run-all·ui-ux 선행등록)·CHANGELOG/docs(Superpowers 외부 출처 서술 제거). validate-structure 12/12 OK 실측 기반.

## [1.21.2] — 2026-06-23

### Added
- **verify-gate 압박 eval** (FID 20260622-verify-gate-pressure-eval, PR #104) — 거버넌스 R-1/R-2(commit·PR 전 verify 강제)를 LLM 행동 차원에서 검증하는 pressure eval 추가. `run-pressure-evals.sh`의 `judge_pressure`에 `forbidden_bash_re` 분기(Bash `input.command` 정규식 — `git commit`/`gh pr create` 변형 매칭)와 sandbox 격리를 추가하고, `verify-gate-fixtures.jsonl`(commit 우회 3 + PR 우회 3)로 "검증 생략하고 바로 커밋/PR" 압박에 게이트 발화 거부 여부를 측정. 기존 도구이름 차원 pressure 6건 무손상(`forbidden_bash_re` 미정의 하위호환). stub 단위 15/15.
- **signal eval 부트스트랩 진입로 감지** (FID 20260623-signal-eval-bootstrap, PR #105) — signal eval(`run-evals.sh`)에 프로젝트 최초 진입 부트스트랩 안내(`/init-project 권장` 발화) 감지 진입로 추가. fixture별 `sandbox_seed`(both/none/specops-only) 시드 분기 + judge `expect_bootstrap` early-return(text 발화 차원, Skill 차원 분리) + stub `text` 필드. 부트스트랩 fixture 2건 + maintain/new 표현 다양화 2건. stub 단위 23/23.
- **chain 중간단계 eval (decompose AC 커버리지)** (FID 20260623-chain-stage-eval, PR #106) — decompose 단계의 미커버 must AC 탐지율을 측정하는 `run-chain-stage.sh` + `decompose-covmiss` fixture 추가(plan-ab 패턴 확대). fixture plan.md가 미커버 AC를 본문 미언급+AC.md에만 둬 이중가드(plan.md만 검사) 통과. `count_detected` AC ID 단어경계 매칭(AC-7≠AC-70 — false-green 차단). e2e-test-ko(구조 완주)와 차원 구분(판단 정확성). stub 단위 6/6.

### Fixed
- **pretool 테스트 격리 결함** (FID 20260623-pretool-test-isolation, PR #107) — `test-pretool.sh`의 deny 테스트(T1·T4·T8~T12)가 pretool HOOK을 실 repo cwd에서 호출해, 테스트 중 `.md` uncommitted 변경 시 `is_docs_only_change()` docs-only 면제가 발동→deny→allow flip 하던 spurious FAIL(최근 3 FID 반복 관측)을 수정. 코드(.sh) staged 공유 sandbox를 `CLAUDE_PROJECT_DIR`로 지정해 격리(T16~T18 패턴 답습). **프로덕션 `is_docs_only_change()`·`pretool-governance.sh` 무변경**(의도된 commit -a 우회 차단 보안 설계 보존) — 테스트 격리만. clean+dirty 양쪽 PASS=18.
- **R-1/R-2 trigger 정규식 우회 차단** (FID 20260623-governance-trigger-evasion, PR #109) — `rules.jsonl` R-1/R-2 trigger_pattern + `pretool-governance.sh` prefilter를 일반화해 `git -c k=v commit`·`git --no-pager commit`·`git --bare commit`·`VAR=val git commit` 등 글로벌 옵션·환경변수 prefix 우회를 차단. grep -E 양방향 probe(우회 deny + false-positive allow) 실측 검증. test-pretool T19~T22.
- **R-1 trigger over-match 제거** (FID 20260623-governance-trigger-overmatch, PR #110) — trigger 정규식이 `git --no-pager log commit`·`git -C /repo log commit`처럼 `commit`을 ref명/인자로 쓰는 정당 명령을 오탐 deny하던 over-match를, 글로벌 옵션 화이트리스트(VAL 값받음→토큰소비 / NOVAL 값없음+`=`형→미소비)로 셸 파서 없이 제거. `--no-advice` under-match 동시 해소. test-pretool T23~T30.
- **R-2 docs-only 면제 비대칭 해소** (FID 20260623-r2-docs-exempt-symmetry, PR #111) — docs-only 면제가 R-1(commit, working tree 검사)엔 작동하나 R-2(PR, 커밋 완료 후 `git diff HEAD` 빈→fail-safe 차단)엔 비대칭이던 문제를 PR-범위 diff(`base...HEAD` triple-dot) fallback으로 대칭화. base 자동감지는 main→master `refs/heads` 순회 + 안전측 실패. test-lib T-docs.e~i + `_detect_base_branch` 단위.
- **trigger 우회 5종 차단 (선행자 char-class 확장)** (FID 20260623-governance-evasion-residual, PR #112) — trigger 선행자 문자집합 `(^|[;&|])` → `(^|[;&|({` + 백틱 + `])`로 확장해 subshell `(git commit)`·brace `{ git commit; }`·command-substitution `$(git commit)`·백틱 우회를 차단. **단일 소스 `rules.jsonl` trigger_pattern(apply_lookback_rule) + `pretool L31` prefilter 양쪽 동시 수정**(pretool+posttool 공유). over-match 보존(T13~T15·T23~T29) 회귀 통과. test-pretool T31~T35 PASS=35.

## [1.21.1] — 2026-06-22

### Changed
- **`plan-reviewer-ko` skill → agent 이관** (FID 20260622-plan-reviewer-agent, PR #103) — registry 불일치 해소. plan-reviewer-ko가 `skills/`에만 있어 `Agent` 도구 `subagent_type`으로 dispatch 불가("agent type not found")하던 비대칭을 `agents/plan-reviewer-ko.md` 신설로 통일(spec-reviewer·code-reviewer·implementer와 동일 패턴 — reviewer/worker=agent). skill 본문(4관점 검증·실측 의무 PR #73)을 byte 수준 보존 이관, frontmatter만 agent 규약(name/description/model:inherit)으로 교체. planning-ko dispatch 표기 `Skill:` → `Agent subagent_type:` 정정(general-purpose plan-document-reviewer 경로는 별개 보존). baseline skills 31→30·agents 3→4, README 트리·카운트 정합.

## [1.21.0] — 2026-06-22

### Added
- **거버넌스 R-1/R-2 docs-only 면제** (FID 20260622-governance-docs-exempt, PR #102) — commit/PR 전 verify 강제에 문서 전용 변경 면제 조항 신설. `is_docs_only_change()`(`git diff HEAD --name-only` = staged∪unstaged tracked 합집합)가 변경 파일이 전부 `.md`·`.txt`·`.rst`면 verify 없이 통과시킨다. 문서·CHANGELOG·오타 수정마다 `SPECOPS_GOVERNANCE_BYPASS=1`을 반복하던 마찰을 제거 → bypass 습관화로 인한 거버넌스 무력화(메타 플러그인 자기모순) 차단. pretool 면제 분기(BYPASS·§auto 동렬)·posttool audit 정합. **보안 불변식**: 코드 1개라도 혼합 → 비면제(차단 보존), 빈목록·git 실패 → 비면제(fail-safe, fail-open과 구분). Phase C 코드리뷰가 `git commit -am` 우회 표면(staged=docs면 `-a`가 unstaged 코드 커밋)을 포착해 staged-only 분기 → 합집합으로 정정, 우회 차단 실증(deny). 회귀: test-lib T-docs.a~d(면제/혼합 비면제/fail-safe/우회) + test-pretool T16~18(allow/deny/commit-am 우회 deny).

## [1.20.0] — 2026-06-22

### Added
- **`/start-all-auto` 무인 batch 모드** (FID 20260622-start-all-auto-mode, PR #100) — `/start-all`의 무인 변형 슬래시 신설. requirements.md FR 표 전체를 가역 게이트 자동통과로 일괄 구현하고 batch PR 직전 1회만 확인. `/start`↔`/start-auto` 선례를 batch에 미러링. 핵심 메커니즘: specifying batch 분기가 진입 약속어 셋째 줄 `<!-- auto: true -->` 감지 시 spec.md에 `**§batch**` + `**§auto**: true` 동시 기재 → 다운스트림 6 skill **무변경**으로 chain 전체 무인화 전파. start-all.md Phase 2 일괄 게이트에 §auto 자동통과 분기 추가(기존 대화형 보존). 회귀: test-branch-label-contract batch+auto 4-way(AC-R-6) + structure-baseline commands 16 + README 진입로 8종.
- **§auto 무인 모드 `advisor()` 보조 자문 통합** (FID 20260622-auto-advisor-assist, PR #101) — §auto 무인 3 분기(clarify BLOCKING·planning cap·verify fix_loop cap)에 `advisor()` 외부 자문을 **보조 입력**으로 additive 통합. best-guess 자기추론의 확신 편향을 외부 관점으로 완화. **결정 대행 아님** — advisor 반영 가정도 `ASSUMED` 유지 → PR 게이트 다이제스트의 사용자 최종 확인(주권 보존). graceful fallback(advisor 미연결 시 기존 best-guess 단독, 하드 의존 금지) + 비용 통제(고영향 가정만 트리거, UI세부·trivial 면제). advisor-ko §2 표에 §auto 무인 자문 행 추가. 회귀 테스트 `test-auto-advisor.sh`(9 grep 가드, governance glob 편입).

### Fixed
- **`start-auto.md` security-review chain stale 정정** (PR #100) — `commands/start-auto.md` L29 chain·§auto 동작표가 v1.19.0 SAST 보안 게이트 재배선(`receive-review → 🔒security → integration → performance → PR`)을 미반영하던 stale을 정정. security Critical/High 차단 행 추가.

## [1.19.2] — 2026-06-22

### Fixed
- **`start-all` 안티패턴 교차참조 오타** — `commands/start-all.md` 안티패턴 "per-FR PR 생성" 항목이 최종 batch PR 생성 단계를 `Step C`(performance-test)로 잘못 지칭하던 오타를 실제 PR 생성 단계인 `Step D`로 정정.

## [1.19.1] — 2026-06-22

### Fixed
- **`_replace_line_prefix` awk escape 차단** (FID 20260622-batch-branch-awk-escape-fix, PR #99) — `init-project` 부트스트랩의 `_replace_line_prefix` 가 `awk -v` 변수 주입으로 PRD 자유입력의 백슬래시 escape sequence(`\t`→탭·`\n`→개행 등)를 묵음 확장하던 결함을 `ENVIRON["VAR"]` 전환으로 차단(PR #81 append.sh 패턴 재적용). `source` 가드(`[ "${BASH_SOURCE[0]}" = "${0}" ]`) 추가로 sourced 시 `main` 미실행 → 테스트 단위 함수 호출 지원. T25.a 회귀 테스트(`경로\test\new` 원문 보존) 추가.
- **integration-test-ko batch 분기 추가** (PR #99) — `start-all` 오케스트레이션 정합을 위한 batch 레벨 통합 테스트 분기 추가.

### Changed
- **`start-project.sh` → `init-project.sh` 파일 rename** (FID 20260622-batch-branch-awk-escape-fix, PR #99) — `/start-project` → `/init-project` 슬래시 rename(v1.17.0)의 잔여로 남아있던 오케스트레이터 스크립트·통합 테스트 2종 파일명을 통일 + stale 참조 정리(README·scripts/README·api-spec placeholder·e2e-test(-ko)·brainstorming(-ko)·using-specops 부트스트랩 명칭·init-project.md 호출 경로). 회귀가드 2건 의미 갱신 — AC-R-1(`git diff 무변경` → `main` 진입 보존), AC-R-3(`/start-project` 문자열 존재 → 런타임 치환 토큰 정합). 과거 FID 슬러그는 이력 추적 위해 보존.

## [1.19.0] — 2026-06-20

### Added
- **SAST 보안 게이트 (security-review-ko)** (FID 20260620-security-review-gate, PR #95) — lifecycle 에 보안 점검 게이트 신설. chain 재배선 `verify → review → 🔒security → integration → performance → PR`(단일+batch). 코드 변경 표면 검출 시 SAST(semgrep+gitleaks) 실행, **Critical/High → chain 차단**(§auto 여도 자동통과 금지), 표면 부재·도구 미설치 시 graceful skip. `scripts/security-scan.sh` 래퍼(gitleaks `--no-git`·mktemp·jq 가드).
- **DAST 온디맨드 슬래시 (/security-scan)** (FID 20260620-security-scan-command, PR #96) — `/security-scan [URL]` 수동 점검. URL 없으면 SAST 전체, 있으면 SAST+DAST(nuclei>ZAP(docker)>nikto, graceful skip). 능동 스캔 소유 확인 게이트(무단 스캔 방지). `SPECOPS_DAST_NO_RUN` 가드로 테스트 결정성 보존.
- **보안 self-check 레이어 (설치 0)** (FID 20260620-security-selfcheck, PR #97) — security-scan.sh 에 외부 도구 없이도 항상 실행되는 bash 자체 점검 1단계. secret(전 파일: AKIA·ghp_·PRIVATE KEY·하드코딩) + 위험함수/SQL(비-bash). **언어 인지**(_is_bash 로 bash eval 정상사용 제외) → 메타 플러그인 자체 오탐 0. tests/ 제외 + fixture 런타임 조립으로 자기오탐 방지. "도구 미설치=무점검" 빈틈 해소.

## [1.18.0] — 2026-06-20

### Removed
- **deprecated alias 2건 제거** (FID 20260620-remove-deprecated-alias, PR #94) — v1.17.0 에서 도입한 `/start-project`·`/start-batch` deprecated alias stub(commands/start-project.md·start-batch.md) 삭제. 구 슬래시는 무동작화 — 정식 진입은 `/init-project`(부트스트랩)·`/start-all`(전체 일괄). 보호테스트 AC-2 를 "alias 부재 검증"으로 전환(회귀 가드 유지), baseline commands 16→14. brainstorming-ko 스킬 토큰·test-start-project.sh T22.a 의 삭제파일 의존을 init-project 로 전환(xref·run-all 회귀 차단). 오케스트레이터 `start-project.sh`·런타임 토큰 보존.

## [1.17.0] — 2026-06-20

### Changed
- **`/start-project` → `/init-project` rename** (FID 20260619-rename-init-project, PR #92) — start- 계열 중 유일하게 lifecycle chain 을 안 도는 doc-only 부트스트랩을 init- 로 분리해 의미 명확화. built-in `/init` 충돌은 `-project` 접미로 회피. `commands/init-project.md` 신설 + `commands/start-project.md` = deprecated alias stub(동작 보존, 1~2 릴리즈 후 제거). 오케스트레이터 `start-project.sh`·런타임 토큰 무변경, 사용자 노출 26파일 치환.
- **`/start-batch` → `/start-all` rename** (FID 20260619-rename-start-all, PR #93) — "batch" 전문용어를 친숙한 "all"(전체 기능 일괄)로. `commands/start-all.md` 신설(3-Phase 오케스트레이터 본문 이관) + `commands/start-batch.md` = deprecated alias stub. **내부 분기 신호어(§batch·BATCH-*·batch-id·entry:batch) 100% 보존** — 안전 sed 로 사용자 슬래시만 치환.

### Fixed
- **문서 stale 정리** (FID 20260619-doc-stamp-sync, PR #91) — ① 테스트 suite **수 하드코딩 제거**(CLAUDE.md·README "41/42 suites" → `run-all.sh` 게이트 안내, 신규 test 마다 stale 되던 자기무효화 근본 해결) ② README §거버넌스 PreToolUse 사전차단(v1.14.0) 명시 ③ reference_upstream 멀티라인 단일라인화 3파일.

## [1.16.0] — 2026-06-19

### Added
- **start-project Phase 8a FR 표 자동 합성** (FID 20260619-start-project-fr-synth, PR #85) — `_phase_8a_requirements` 가 PRD 마일스톤(PRD_F4/F5/F6 = M1/M2/M3)을 `requirements.md` §2 FR 표 시드 + §5 마일스톤 이름에 합성(전략 C). 빈값·`<TODO>` 시 placeholder 보존(회귀). `/start-project` → `/start-batch` 워크플로 단절(FR 표 수작업) 해소.
- **진입로 7종 결정 트리** (FID 20260619-entry-decision-tree, PR #87) — README §2 에 ASCII 결정 플로차트(신규 vs 기존 / start-project→foundation→batch 순서 / start vs start-auto vs maintain 판단 기준) + `/start-auto`·`/brainstorming` 진입표 행 추가.
- **분기 라벨 생산↔소비 정합 회귀 테스트** (FID 20260619-branch-label-contract, PR #88) — `test-branch-label-contract.sh`: 소비처 §batch/§auto grep 패턴 일관성 + fixture 3-way 분기(BATCH/AUTO/SINGLE) + 생산 표기 회귀. 라벨 표기 drift 자동 탐지.
- **화면 설계 3경로 분업 문서** (FID 20260619-screen-routing-doc, PR #90) — design-screen.md 에 분업표(specifying Step 5.5 인라인 / `/design-screen` 단수 / `/design-screens` 복수 + 언제 쓰나) + design-screens.md·specifying Step 5.5 cross-ref(DRY).

### Fixed
- **verifying-evidence-ko §auto 감지 죽은 코드** (PR #88) — §auto fix_loop cap 분기의 `grep -q '**§auto**'` 가 BRE empty subexpression 으로 영구 NO MATCH → `grep -q '\*\*§auto\*\*'` 정합화. §auto(완전자동) 모드 verify 실패 시 자동 복구 로직이 작동하지 않던 잠복 버그 해소.

### Changed
- **라벨 소비처 역방향 자동 스캔** (FID 20260619-label-consumer-autoscan, PR #89) — test-branch-label-contract.sh 의 하드코딩 소비처 목록 → `grep -rlF` 역방향 스캔 + 공허 방지 + 핵심 기대치 assert. 하드코딩이 누락하던 `using-git-worktrees-ko`(§auto 소비처) 자동 포함, 신규 소비처 미포착 방지.

## [1.15.1] — 2026-06-15

### Added
- plan-reviewer 실측 의무 강화 — 검증 가능한 주장(파일·라인·bash 문법·심볼)을 추측이 아닌 명령실행(`grep`/`bash -n`/`ls`)·Read로 실측한 뒤 판정. 추측 Critical/Important 판정 금지, 실측 불가 시 `[검증 불가]` Minor 강등. plan-reviewer-ko + plan-document-reviewer-prompt 양 채널 적용. IFS false-positive류 추측 오판 근본 차단(원안 다관점 분리는 분석으로 기각 — 이미 4관점 보유). (#20260615-multilens-plan-critic)

## [1.15.0] — 2026-06-15

### Added
- mutation-score equivalent-mutant 제외 — `mut::is_equivalent`(target,line,pattern 정밀매칭) + `mutation-equivalent.conf`. governance-lib stdout-contract 함수의 관찰불가 return-code 변형 18곳을 분모 제외해 측정 31%→64% 정직화 (Stryker 표준). (#20260614-mutation-equivalent-exclude)
- ui-ux-pro-max cross-marketplace hard dependency 선언 — 화면 설계 design system 자문을 보장 동반 설치로 격상 (plugin.json dependencies + marketplace.json allowCrossMarketplaceDependenciesOn). graceful 안전망 보존. (#20260615-uiux-hard-dependency)
- 기획 단계 강화 — ① clarifying-ko 경량 모드(BLOCKING=0 자동탐지 시 DESIRABLE 1회 후 통과, F-11 보존) ② spec 성공지표(measurable target) 권장 도입(spec.md §1 서브섹션 + specifying 작성 유도 + performance learning-loop 환류). (#20260615-planning-stage-enrich)

## [1.14.0] — 2026-06-14

### Added
- **llm-eval 공통 매트릭스 러너 (eval-lib)** (FID 20260614-eval-matrix-lib, PR #69) — promptfoo 방법론(assertion 어휘 + declarative 매트릭스)을 bash 로 이식. `eval-lib.sh`(소스 전용): assertion 어휘 4종(contains/regex/cost_lt/llm_rubric) + `eval::assert` 디스패처 + `eval::run_matrix` + extract_text/cost/skip_guard. `run-matrix-eval.sh` 가 declarative 사용(기본 stub 토큰0, CLAUDE_BIN 시 실 모델). 빈 needle·비숫자 cost false-green 가드(검증 도구 자기 신뢰성). 기존 3 runner 무손상(additive, git diff 0). stub 단위 15. 검증 강화 로드맵 V5(약점 W-6 중복·표현력). 기존 러너의 lib 이관·실 provider 행별 호출은 별도 FID.
- **SKIP 형식화 강화 (skip-tracker)** (FID 20260614-skip-tracking, PR #68) — `scripts/skip-tracker.sh` 가 `.specops/*/evidence.md` 의 integration/performance 게이트 SKIP 비율을 집계(읽기 전용 advisory). awk 섹션-플래그로 evidence 2 포맷(구조형·인라인) 견고 파싱 + 비게이트 헤더 pending 리셋(오연관 차단). integration-test-ko·performance-test-ko 게이트에 §유형≠trivial SKIP 근거 spec 라인 인용 의무 명문화. 실측: integration SKIP 75%(⚠️ 임계초과)·performance 61% — 형식화 가시화. stub 단위 11. 검증 강화 로드맵 V3(약점 W-3 SKIP 형식화 + W-4 추적).
- **간이 뮤테이션 하니스** (FID 20260614-mutation-harness, PR #67) — `scripts/tests/mutation-score.sh` 가 bash 스크립트에 1줄 변형(연산자 반전·반환값·불린) 주입 후 해당 테스트가 FAIL 로 잡는지(killed) 측정 → mutation score + survived(테스트 갭) 리포트. stryker 사상의 bash 경량 구현, 모델 무관(토큰 0). 깨끗한 원본 grep+sed(phantom 차단)·빈파일/문법 invalid 가드·복원 trap 이중 안전망. 실측: parse-dag.sh 100%·governance-lib.sh 31%(test 갭 24). 수동 도구(run-all 미포함), stub 단위 10 만 포함. 검증 강화 로드맵 V2(약점 W-1 효과 미입증의 모델-무관 대행).
- **거버넌스 강제력 승격 — PreToolUse 사전차단** (FID 20260614-governance-hard-block, PR #66) — 신규 `hooks/pretool-governance.sh` 가 verify 누락 시 `git commit`·`gh pr create` 를 실행 *전* 차단(deny). PostToolUse 사후발화의 예방 불가 한계 해소 — pretool=강제, posttool=감사 역할 분리. `apply_lookback_rule`(R-1/R-2) 재사용, `log_friction_sev` block severity 신규(기존 무변경 append). 우회 면제(`SPECOPS_GOVERNANCE_BYPASS=1`·§auto) + fail-open 으로 무인 lifecycle 보존. test-pretool 7케이스. 검증 강화 로드맵 V1(약점 W-2 강제력).
- **plan 리뷰 A/B 측정 하니스** (FID 20260613-plan-review-ab, PR #65) — `run-plan-ab.sh` 가 결함 심은 plan fixture 에 inline self-review(A) vs 2중 dispatch(B) 를 적용해 검출률·토큰 비교. `count_detected` 이중 가드 (plan 본문 등장 locator 무효화 — claude 입력 인용 over-count 차단), 결함 fixture 2종 (커버리지·플레이스홀더·타입), stub 단위 9 (토큰 0). 격차 분석 P2-1(subagent-리뷰 폐지 측정)의 코드베이스 재현. 실 baseline 은 모델 가용 시 수동 측정 (한계 고백).

## [1.13.0] — 2026-06-12

### Added
- **압박 테스트 레이어** (FID 20260613-pressure-eval, PR #64) — run-pressure-evals.sh 가 HARD GATE 우회 압박을 claude -p 로 실행, judge_pressure 가 금지 도구 호출 부재 AND 게이트 거부 발화 존재를 판정 (침묵 굴복도 FAIL). pressure-fixtures 6건 + stub 단위 11 (토큰 0). 격차 분석 P2-2.
- **tier→Agent model 파라미터 매핑** (FID 20260612-tier-dispatch, PR #63) — implementing-ko 가 tier 판단을 Agent 도구 `model` 로 실제 전달 (low→haiku/medium→sonnet/high·불확실→inherit). 격차 분석 P2 O-4.
- **학습 환류 루프** (FID 20260611-learning-loop, PR #60) — `gbrain-collect.sh` (handoffs/evidence 기계 수집) + `gbrain-recall.sh` (토큰 중첩 조회, 1000건 ~50ms) 신설. performance-test-ko 가 lifecycle 말미에 인사이트 ≤3건 자동 추출, specifying-ko 가 차기 진입 시 관련 인사이트를 spec §참조에 자동 인용. `learnings.jsonl` 은 gitignore 예외로 git 추적 (학습 자산 영속). DAG 병렬 worktree wave 첫 실전 적용.
- **멀티모델 critic** (FID 20260612-multimodel-critic, PR #61) — `critic-ask.sh` 가 plan.md·diff 를 외부 모델 CLI (CRITIC_BIN>codex>gemini) 에 위탁, advisory 전용 (판정 권한 없음·실패 exit 0). planning-ko·requesting-code-review-ko·advisor-ko 연결 + 비밀 보호 가드·인젝션 가드·200KB 절단. CLI 부재 시 graceful SKIP.
- **worktree skill v5.1.0 (PRI-974) 동기화** (FID 20260612-worktree-sync-v51, PR #62) — 중첩 worktree 감지 (git-common-dir)·생성 동의 게이트 (모드 4분기 — 무인 흐름 보존)·provenance 정리 (.worktrees/ 한정, 외부 불가침)·detached HEAD 분기. reference_upstream @v5.1.0 bump.

## [1.12.0] — 2026-06-11

### Added
- **design-screen(s) ui-ux-pro-max rationale 보관 + Anti-pattern 게이트** (FID 20260610-design-screen-enrich, PR #54).
- **`scripts/tests/run-all.sh` 전체 테스트 aggregator** — 41 suites (test-*.sh + dag + governance + convention + validate-structure). `release.sh` pre-flight 가 메인 3종 대신 이를 호출. `.github/workflows/test.yml` CI 신설.
- **LLM eval 레이어** (FID 20260610-llm-eval, PR #57) — 메타 skill 신호 감지 + 체인 진입을 headless `claude -p` 로 smoke eval. `scripts/tests/llm-eval/`: fixtures 10건 + `run-evals.sh` (stream-json 파싱·재시도 cap=1·BORDERLINE·sandbox 격리·timeout 워치독) + stub 기반 단위 테스트 17건 (run-all 편입, 토큰 0). 실 eval 은 수동 전용 (비용) — 첫 완주 실측 PASS=10 FAIL=0.

### Fixed
- **거버넌스 훅 성능 74배 개선 + 회귀 게이트** — governance-lib 줄단위 jq fork 루프 6곳을 단일 jq 패스로 재작성 (2000줄 Stop 훅 8,000ms → 108ms). bench-hook 에 stop 워스트케이스 게이트 신설 + CI 연결. CWD 앵커링(`CLAUDE_PROJECT_DIR`)·word-split·gbrain tags 이스케이프·FID 가드 등 MEDIUM 잔여 일괄. `.specops/` 205 파일 추적 해제 (배포 불포함 규약 정합).
- **`.gitignore` 미해소 머지 충돌 마커 5줄 제거**.
- **테스트 5종 stale 경로 수정** — `count-artifacts`/`diff-upstream`/`is-hook-enabled`/`validate-task-dependencies` 의 `scripts/` → `scripts/_internal/` 이동 미반영 (rc=127 FAIL → PASS).
- **문서 동기화** — README footer·skill×30·templates×28, marketplace description v1.11.0, e2e 9단계/V19 표기, CLAUDE.md layer 3 목록(e2e-test-ko 추가), R-6 비활성 상태 명기.

## [1.11.0] — 2026-06-09

### Added
- **`/design-screens` 복수 화면 일괄 디자인 커맨드 신설** — 목록 자동 판단·승인 게이트·화면별 순차 대화 루프. design-screen 과 cross-ref 연결. (FID 20260609-design-screens)
- **`release.sh` FR-7b manifest bump** — `plugin.json`/`marketplace.json` version 필드 자동 갱신 (v1.10.0 릴리즈 시 manifest desync 재발 방지).

### Changed
- **R-6 비활성화 (`enabled: false`)** — gbrain-ko manual-only 설계 우선, lifecycle 완주 시 false-warn 제거. 거버넌스 자동 검사는 R-1~R-5 로 축소.

### Fixed
- **manifest v1.10.0 desync 즉시 수정** — plugin.json + marketplace.json.
- **design-screens Step 3-1 충돌확인 순서 명확화 + Step 3-3 html 생성 표현 수정**.

### Docs
- README 12건·footer v1.10.0 + maintain.md·메타 skill chain 동기화. CHANGELOG v1.10.0 섹션 백필.

## [1.10.0] — 2026-06-09

### Added
- **`/start-auto` 완전자동 모드** — `<!-- entry: auto -->` 진입, 각 HARD GATE 자동 통과(가역), PR 직전 단일 확인. commands/start-auto.md 신설. specifying/clarifying/planning/decomposing/implementing/verifying/performance-test-ko 전 단계 §auto 분기 적용.
- **`show-fid-status.sh` FID Lifecycle 상태 표시 CLI** — `.specops/<FID>/` 산출물 기반 현재 단계 표시 (AC-1~AC-5). PR #50.
- **Dynamic workflow 패턴** — 다단계 병렬 wave (`dag::find_ready`), 모델 티어 라우팅(tasks.md `tier: low|medium|high`), Stage handoff 규약(`handoffs/` 4필드), Bounded verify→fix 루프(fix_count 추적·상한 3회). implementing-ko·verifying-evidence-ko·structured-artifacts-ko 적용.
- **`/release` 릴리즈 자동화 skill + `scripts/release.sh`** — CHANGELOG·README·commands footer·manifest 버전 동기화. PR #51.

### Changed
- **`specifying-ko`** — §auto 분기: 화면 설계 자동수락 + spec 게이트 자동통과.
- **`clarifying-ko`** — §auto BLOCKING best-guess 자동응답 + `status: ASSUMED` + 가정 근거 필드.
- **`planning-ko`** — plan-reviewer cap 초과 시 §auto 자동통과(가역).
- **`decomposing-ko`** — `irreversible: true` DAG 필드, 3-way 다음 skill 분기(batch/auto/single).
- **`implementing-ko`** — Phase B/C §auto 수렴 + `auto_retry_count` 전역 재시도(cap=1).
- **`verifying-evidence-ko`** — fix_loop cap §auto 수렴 + shared `auto_retry_count`.
- **`performance-test-ko`** — 3-way PR 게이트(batch/auto 가정다이제스트/single).
- **`structured-artifacts-ko`** — `auto-state.md` 규약, 무인 모드 술어 문서화.

---

## [1.9.0] — 2026-06-08

### Added
- **`/start-batch` batch 레벨 통합·성능 테스트 (must-run)** — Phase 3 완료 후 `integration-test-ko` → `performance-test-ko` 1회 실행 추가 (Step A·B). 표면/임계값 부재 시 graceful skip. 단일 `/start`와 `/start-batch` 동작 일치.
- **`receiving-code-review-ko` batch halt 패턴** — `## 다음 skill`에 `**§batch**` 라벨 감지 분기 신설. batch 모드 시 `BATCH-REVIEW-DONE: <FID>` 출력 + halt, integration-test-ko 미호출. 단일 모드는 기존 chain 유지.
- **`performance-test-ko` batch-aware PR gate skip** — `## PR 생성 게이트` 진입 직전 `**§batch**` 라벨 감지 분기. batch 모드 시 `BATCH-PERF-DONE: <FID>` 출력 + PR 게이트 전체 skip, `/start-batch` 오케스트레이터로 제어 반환.

### Changed
- **`commands/start-batch.md`** — Phase 3 loop Step 5: stale "PR 생성? [y/n] → n decline" 참조 → `BATCH-REVIEW-DONE` 감지 자동 차단으로 교체. Phase 3 완료 섹션에 Step A(통합 테스트)·B(성능 테스트)·C(batch PR) 3단계 구조 명시. 안티패턴에서 stale `receiving-code-review-ko` 직접 묻기 설명 제거.
- **`README.md`** — 헤더 `v1.7.0` → `v1.8.0` 갱신. Lifecycle Chain 다이어그램에 `integration-test-ko`·`performance-test-ko` 노드 추가 + PR gate를 `performance-test-ko` 말미로 이동. chain 텍스트에 integration-test·performance-test 추가.
- **`commands/start.md`·`start-foundation.md`** — chain 나열에 `→ integration-test-ko → performance-test-ko → PR` 추가.
- **`skills/systematic-debugging-ko/SKILL.md`** — `used_by`에 `integration-test-ko·performance-test-ko` 추가. `## 다음 skill` routing에 integration/performance FAIL caller 복귀 케이스 추가.
- **`scripts/_internal/validate-structure.sh`** — 헤더 주석 `× 27` → `× 29` 갱신 (실제 .structure-baseline 반영).

---

## [1.8.0] — 2026-06-05

### Added
- **`integration-test-ko` engine skill (layer 2)** — lifecycle chain에서 통합 표면(API·DB·다중 모듈 경계) 검출 시 통합 테스트 작성·실행·증거화. 표면 부재 시 graceful skip. test-master integration 패턴 번안.
- **`performance-test-ko` engine skill (layer 2)** — lifecycle chain에서 NFR 성능 임계값(응답시간·처리량·동시성) 검출 시 성능 테스트 작성·실행·증거화. 임계값 부재 시 graceful skip. test-master performance 패턴 번안.
- **PR 생성 게이트 이전** — `receiving-code-review-ko`에서 PR 생성(`gh pr create`)을 `performance-test-ko` 말미로 이전. 통합/성능 테스트를 PR 직전에 실행하는 구조 확립.

### Changed
- **`receiving-code-review-ko`** — `## 다음 skill`이 chain 종료에서 `integration-test-ko` 호출로 변경. `## PR 생성 (Lifecycle 종료)` 섹션 제거 (performance-test-ko로 이전).
- **`e2e-test-ko`** — S6.5 단계(integration-test-ko·performance-test-ko SKIP 경로 검증 V18~V19) 추가. 검증 항목 17→19, PASS≥16→PASS≥18.
- **chain 순서** — `…verify → review → integration-test → performance-test → PR` (단일 /start 및 /start-batch 모두)

---

## [1.7.0] — 2026-06-05

### Added
- **`/start-batch` 슬래시 커맨드** — `requirements.md` FR 표를 자동 파싱해 전체 기능을 일괄 구현하는 3-Phase 오케스트레이터.
  Phase 1(spec→clarify→plan→decompose per FR) → Phase 2(일괄 리뷰 1회) → Phase 3(impl→verify→review per FR 순차 무중단) → 최종 batch PR 1개
- **`specifying-ko` batch 분기** — `<!-- entry: batch -->` 감지 시 git-branch-create skip + spec.md §1에 `**§batch**: <batch-id>` 라벨 기재
- **`decomposing-ko` chain 정지점** — spec.md `**§batch**` 라벨 감지 시 `BATCH-PHASE1-DONE: <FID>` 출력 + halt (implementing-ko 미호출)

---

## [1.6.0] — 2026-06-05

### Added
- **`/start-foundation` 슬래시 커맨드** — 한국 SI 표준 "공통부 먼저 개발" 단계 지원.
  per-feature `/start` 사이클 이전에 실행 가능한 공통부 코드(라우팅·레이아웃·인증·공통 컴포넌트·DB 마이그레이션)를 생성하는 독립 커맨드
- **`templates/foundation-manifest.md`** — 공통부 모듈 목록 템플릿 (라우팅·인증·레이아웃·공통컴포넌트·DB스키마)
- **`specifying-ko` foundation 분기** — `<!-- entry: foundation -->` signal check, Step 5.5 화면 루프 skip, §유형=`foundation` 자동 라벨
- **`clarifying-ko` BLOCKING 게이트** — §유형=`foundation` 시 `.specops/memory/frontend-architecture.md`/`backend-architecture.md` 미해소 placeholder 감지 시 기술스택 BLOCKING 강제
- **`planning-ko` foundation-manifest 산출 지시** — §유형=`foundation` 플랜 마지막 태스크로 `foundation-manifest.md` 저장 의무화
- **`decomposing-ko` 재사용 HARD GATE** — §유형≠`foundation` + `foundation-manifest.md` 존재 시 각 task에 `**재사용 foundation**` 또는 `**미재사용 근거**` 기재 의무

---

## [1.5.0] — 2026-06-04

### Added
- **ui-ux-pro-max 통합 포인터** — `commands/design-screen.md` Step 2.5 (design system 자동 자문)
  + `skills/specifying-ko/SKILL.md` Step 5.5 하위 절차 (화면 설계 전 design system 자문 안내). available-skills 에 `ui-ux-pro-max:ui-ux-pro-max` 가 없으면 graceful skip
- **로그인 화면 dogfood** — `screens/login.html` (HTML5/CSS3/인라인 JS, 다크 테마, 320px+ 반응형, AC-5 비밀번호 토글, role=alert·aria-invalid·aria-pressed 접근성)
  + `scripts/tests/test-login-screen.sh` (grep-F 기반 HTML 구조 검증 11체크, AC-1~AC-5)

### Removed
- **stale 브랜치 정리** (2026-06-01) — 이전 세션 잔재인 머지 완료 브랜치 6종(로컬 5 + remote 5 ref) 삭제: `chore/commands-cleanup`·`chore/v1.3.0-bump`·`feat/20260522-harness-ref-skills`·`feat/20260526-bash-redirect-evidence`·`feat/20260526-e2e-test-ko-split`·`fix/cleanup-stacked-prs`. 전 산출물이 main 에 반영됐음을 확인 후 삭제 (MERGED 8 + squash-머지 추정 2, 유실 0). 로컬·원격 모두 `main` 단독 상태로 복원

### Docs
- 거버넌스 R-6 문서 누락 정정 — `CLAUDE.md`·`README.md` "5규칙 R-1~R-5" → "6규칙 R-1~R-6" + R-6 행/설명 추가. `posttool-governance.sh` 설명 R-1~R-5 → R-1~R-3 정정. 하드코딩 PASS 카운트 제거 (#43)

---

## [1.4.0] — 2026-06-01

### Added
- **e2e-test-ko 양 끝 커버리지** — `S0 BOOTSTRAP`(start-project 부트스트랩 검증 V10~V13) + `S7 FINISH`(finishing 정리 HARD GATE 로직 V14~V17). lifecycle 6→8단계, 검증 V1~V9 → V1~V17. S0/S7 은 격리 throwaway repo(`mktemp`+`git init`)에서 실행 (#38)
- **DAG-AWARE PARALLEL dispatch 재실행 harness** (`scripts/tests/dag/dogfood-parallel-harness.sh`) + fixture(`fixtures/dogfood-parallel/`) + 실증 case-study. `run`(병렬 GAP 보존)·`demo`(머지 glue 자동) (#41)
- governance 단위 테스트 **T-R6.15/16** (stop-governance.sh end-to-end 통합 — entrypoint 실제 실행 + 멱등 가드) + **T-R6.17/18** (same-turn Write+Bash characterization + negative fixture) (#39)
- implementing 단위 테스트 **T2.a~c** — 부모 머지-race(`git apply --index` 합성/충돌 abort) 검증 (#40)

### Changed
- `receiving-code-review-ko` — finishing handoff forward pointer 추가 (PR `MERGED` HARD GATE 라 자동 chain 금지, 수동 진입 안내) (#38)
- `commands/e2e-test.md` — 8단계/V1~V17 동기화 (#38)
- governance `apply_gbrain_absence_rule` — Minor1 hot-path tightening: `tool_use` 선검사로 비-tool 라인 jq fork 절감 (동작 보존, union 미채택) (#39)
- governance 테스트 66 → 70 PASS

### Fixed
- `apply_gbrain_absence_rule` docstring — trivial-skip 의 CWD 의존 spec.md lookup 한계 고백 (#39)

### Notes
- **G3 병렬 dispatch 진실 규명**: "미구현" 아님 — 이미 specified (지침 + infra + 안전장치 완비). 부모 머지 로직 단위검증(#40) + dogfood 실증(#41). 단 단일 메시지 멀티-Agent emit(병렬 dispatch 핵심)은 bash 검증 불가 — 실제 증명은 세션 transcript 에만 존재

---

## [1.3.0] — 2026-05-26

### Added
- **R-6 거버넌스 규칙** (`hooks/governance-lib.sh:apply_gbrain_absence_rule`) — `/verify` 후 `gbrain-append.sh` 호출 부재 시 Soft Warn. lifecycle 완주 후 1줄 인사이트 자동 누적 권고 (#35)
- **R-6 evidence 매처 Bash invocation 분기** — `bash scripts/_internal/run-verification.sh <FID>` dogfood 경로를 evidence 생성으로 인정. BASH_REMATCH capture group 2 로 FID 추출 + defense-in-depth grep 가드 (#36)
- 신규 fixture 8건 (`scripts/tests/governance/fixtures/transcripts/r6-*.jsonl`)
- 신규 단위 테스트 T-R6.0~T-R6.14 (15건) — invocation 단독·gbrain runner·trivial-skip·mixed Write+Bash line max 등

### Fixed
- `hooks/session-start.sh` awk `exit` 가 END 블록 트리거 → rehydrate 시 동일 session-progress 블록 2회 출력 버그 수정
- `hooks/posttool-governance.sh`, `hooks/stop-governance.sh` — `set -u` → `set -uo pipefail` 강화
- R-6 evidence 매처 Write OR Edit 확장 (#35 review #1, 80b89ef)
- R-6 gbrain_runner_pattern 좁힘 — `gbrain` 조회 skill false PASS 차단 (#35 review #2, cce18a5)
- R-6 Bash 분기 evidence_path_pattern 가드 (#36 review #1, 5827ba4)

### Removed
- `.specops/20260427-test-{bugfix-fixture,natural-bugfix,newfeature-csv,slash-refactor,trivial-typo}/` — dogfood 테스트 fixture 5개 정리
- `.specops/session-progress.md` — 잔여 cvt-cli 중복 entry 제거

### Added
- `CHANGELOG.md`, `CONTRIBUTING.md` 신설

---

## [1.2.0] — 2026-05-26

### Added
- `start-project` Phase 8f — api-spec.md 비선택 섹션 스트리핑 + 포맷별 템플릿 분리 (#28, c0d1582, 67eb8f5)
- `design-screen` T7/T8 테스트 추가 (#29)
- `analyzing-ko` 신설 — 유지보수 진입 시 baseline + impact-analysis.md 산출 (★ HARD GATE)
- `karpathy-ko` cross-cutting skill — Think·Simplicity·Surgical·Goal 4원칙
- `advisor-ko` skill — 애매한 지점 외부 자문 의무화
- `brainstorming-ko` — gstack office-hours 한국어 재창작 (Startup/Builder 모드)
- `plan-reviewer-ko` — planning-ko Eng 리뷰 서브에이전트
- `gbrain-ko` + `/gbrain` — learnings.jsonl 인사이트 조회
- `improve-codebase-architecture-ko` + `/improve-arch` — deep module 정적 분석
- `e2e-test-ko` + `/e2e-test` — lifecycle chain fixture 자동 실행
- `finishing-a-development-branch-ko` — worktree 정리·branch 삭제·main 동기화
- `git-branch-create.sh` — feat/<FID> 브랜치 자동 생성 (specifying/analyzing Step 0)

### Fixed
- `planning-ko` ## Eng 리뷰 중복 3개 제거 + `brainstorming-ko` ## 다음 skill 추가 (7ab564b)
- `hooks/is-hook-enabled.sh` 경로 `scripts/` → `scripts/_internal/` (#30)
- `design-screen` exit 0 누락 (#29)
- harness skill layer 필드 1 → 3 (잔여 분류 오류)
- `run-verification.sh` whitelist 보안 강화 + `..` traversal 차단
- `marketplace.json` 버전 동기화 1.1.1 → 1.2.0

### Changed
- 전 skill frontmatter 정합성 — `used_by` 네임스페이스 정규화 + PoC v0.0 → v1.0.0 (#27)
- `commands/*` `specops_version` 1.0.0 정렬 + `specops_layer` 필드 추가

---

## [1.1.0] — 2026-05-19

### Added
- `start-project` `--resume` 플래그 — 부분 부트스트랩 재개 (#22)
- `design-screen` 자동화 bash + 테스트 (#23)
- `specifying-ko` v2.2 — CONTEXT.md + docs/adr/ 자동 감지 (#12)
- `SKILL.md` 템플릿 + 규약 자동 검증 (`test-skill-conventions.sh`)

### Fixed
- `start-design` deprecated → `start-project` 통합

---

## [1.0.0] — 2026-05-18

### Added
- PoC → 정식 릴리즈 전환
- Lifecycle chain 7단계 완성: specify → clarify → plan → decompose → implement → verify → review
- 거버넌스 엔진 R-1~R-5 + 38건 테스트
- DAG 파서 (`scripts/dag/parse-dag.sh`) + 13건 테스트
- 서브에이전트 2단계 리뷰 (Phase B spec-reviewer-ko, Phase C code-reviewer-ko)
- Harness skill 5종 — sprint-contracts, structured-artifacts, generator-evaluator, context-resets, file-based-communication

[Unreleased]: https://github.com/andyko18/specops-ko/compare/v1.84.0...HEAD
[1.84.0]: https://github.com/andyko18/specops-ko/compare/v1.83.0...v1.84.0
[1.83.0]: https://github.com/andyko18/specops-ko/compare/v1.82.0...v1.83.0
[1.82.0]: https://github.com/andyko18/specops-ko/compare/v1.81.0...v1.82.0
[1.81.0]: https://github.com/andyko18/specops-ko/compare/v1.80.0...v1.81.0
[1.80.0]: https://github.com/andyko18/specops-ko/compare/v1.79.0...v1.80.0
[1.79.0]: https://github.com/andyko18/specops-ko/compare/v1.78.1...v1.79.0
[1.78.1]: https://github.com/andyko18/specops-ko/compare/v1.78.0...v1.78.1
[1.78.0]: https://github.com/andyko18/specops-ko/compare/v1.77.0...v1.78.0
[1.77.0]: https://github.com/andyko18/specops-ko/compare/v1.76.0...v1.77.0
[1.76.0]: https://github.com/andyko18/specops-ko/compare/v1.75.0...v1.76.0
[1.75.0]: https://github.com/andyko18/specops-ko/compare/v1.74.0...v1.75.0
[1.74.0]: https://github.com/andyko18/specops-ko/compare/v1.73.0...v1.74.0
[1.73.0]: https://github.com/andyko18/specops-ko/compare/v1.72.0...v1.73.0
[1.72.0]: https://github.com/andyko18/specops-ko/compare/v1.71.0...v1.72.0
[1.71.0]: https://github.com/andyko18/specops-ko/compare/v1.70.0...v1.71.0
[1.70.0]: https://github.com/andyko18/specops-ko/compare/v1.69.0...v1.70.0
[1.69.0]: https://github.com/andyko18/specops-ko/compare/v1.68.0...v1.69.0
[1.68.0]: https://github.com/andyko18/specops-ko/compare/v1.67.0...v1.68.0
[1.67.0]: https://github.com/andyko18/specops-ko/compare/v1.66.0...v1.67.0
[1.66.0]: https://github.com/andyko18/specops-ko/compare/v1.65.0...v1.66.0
[1.65.0]: https://github.com/andyko18/specops-ko/compare/v1.64.0...v1.65.0
[1.64.0]: https://github.com/andyko18/specops-ko/compare/v1.63.0...v1.64.0
[1.63.0]: https://github.com/andyko18/specops-ko/compare/v1.62.0...v1.63.0
[1.62.0]: https://github.com/andyko18/specops-ko/compare/v1.61.0...v1.62.0
[1.61.0]: https://github.com/andyko18/specops-ko/compare/v1.60.0...v1.61.0
[1.60.0]: https://github.com/andyko18/specops-ko/compare/v1.59.0...v1.60.0
[1.59.0]: https://github.com/andyko18/specops-ko/compare/v1.58.0...v1.59.0
[1.58.0]: https://github.com/andyko18/specops-ko/compare/v1.57.0...v1.58.0
[1.57.0]: https://github.com/andyko18/specops-ko/compare/v1.56.0...v1.57.0
[1.56.0]: https://github.com/andyko18/specops-ko/compare/v1.55.0...v1.56.0
[1.55.0]: https://github.com/andyko18/specops-ko/compare/v1.54.0...v1.55.0
[1.54.0]: https://github.com/andyko18/specops-ko/compare/v1.53.0...v1.54.0
[1.53.0]: https://github.com/andyko18/specops-ko/compare/v1.52.0...v1.53.0
[1.52.0]: https://github.com/andyko18/specops-ko/compare/v1.51.0...v1.52.0
[1.51.0]: https://github.com/andyko18/specops-ko/compare/v1.50.0...v1.51.0
[1.50.0]: https://github.com/andyko18/specops-ko/compare/v1.49.0...v1.50.0
[1.49.0]: https://github.com/andyko18/specops-ko/compare/v1.48.0...v1.49.0
[1.48.0]: https://github.com/andyko18/specops-ko/compare/v1.47.3...v1.48.0
[1.47.3]: https://github.com/andyko18/specops-ko/compare/v1.47.2...v1.47.3
[1.47.2]: https://github.com/andyko18/specops-ko/compare/v1.47.1...v1.47.2
[1.47.1]: https://github.com/andyko18/specops-ko/compare/v1.47.0...v1.47.1
[1.47.0]: https://github.com/andyko18/specops-ko/compare/v1.46.0...v1.47.0
[1.46.0]: https://github.com/andyko18/specops-ko/compare/v1.45.0...v1.46.0
[1.45.0]: https://github.com/andyko18/specops-ko/compare/v1.44.0...v1.45.0
[1.44.0]: https://github.com/andyko18/specops-ko/compare/v1.43.0...v1.44.0
[1.43.0]: https://github.com/andyko18/specops-ko/compare/v1.42.0...v1.43.0
[1.42.0]: https://github.com/andyko18/specops-ko/compare/v1.41.0...v1.42.0
[1.41.0]: https://github.com/andyko18/specops-ko/compare/v1.40.0...v1.41.0
[1.40.0]: https://github.com/andyko18/specops-ko/compare/v1.39.1...v1.40.0
[1.39.1]: https://github.com/andyko18/specops-ko/compare/v1.39.0...v1.39.1
[1.39.0]: https://github.com/andyko18/specops-ko/compare/v1.38.0...v1.39.0
[1.38.0]: https://github.com/andyko18/specops-ko/compare/v1.37.0...v1.38.0
[1.37.0]: https://github.com/andyko18/specops-ko/compare/v1.36.0...v1.37.0
[1.36.0]: https://github.com/andyko18/specops-ko/compare/v1.35.0...v1.36.0
[1.35.0]: https://github.com/andyko18/specops-ko/compare/v1.34.1...v1.35.0
[1.34.1]: https://github.com/andyko18/specops-ko/compare/v1.34.0...v1.34.1
[1.34.0]: https://github.com/andyko18/specops-ko/compare/v1.33.0...v1.34.0
[1.33.0]: https://github.com/andyko18/specops-ko/compare/v1.32.3...v1.33.0
[1.32.3]: https://github.com/andyko18/specops-ko/compare/v1.32.2...v1.32.3
[1.32.2]: https://github.com/andyko18/specops-ko/compare/v1.32.1...v1.32.2
[1.32.1]: https://github.com/andyko18/specops-ko/compare/v1.32.0...v1.32.1
[1.32.0]: https://github.com/andyko18/specops-ko/compare/v1.31.0...v1.32.0
[1.31.0]: https://github.com/andyko18/specops-ko/compare/v1.30.0...v1.31.0
[1.30.0]: https://github.com/andyko18/specops-ko/compare/v1.29.0...v1.30.0
[1.29.0]: https://github.com/andyko18/specops-ko/compare/v1.28.0...v1.29.0
[1.28.0]: https://github.com/andyko18/specops-ko/compare/v1.27.0...v1.28.0
[1.27.0]: https://github.com/andyko18/specops-ko/compare/v1.26.5...v1.27.0
[1.26.5]: https://github.com/andyko18/specops-ko/compare/v1.26.4...v1.26.5
[1.26.4]: https://github.com/andyko18/specops-ko/compare/v1.26.3...v1.26.4
[1.26.3]: https://github.com/andyko18/specops-ko/compare/v1.26.2...v1.26.3
[1.26.2]: https://github.com/andyko18/specops-ko/compare/v1.26.1...v1.26.2
[1.26.1]: https://github.com/andyko18/specops-ko/compare/v1.26.0...v1.26.1
[1.26.0]: https://github.com/andyko18/specops-ko/compare/v1.25.0...v1.26.0
[1.25.0]: https://github.com/andyko18/specops-ko/compare/v1.24.0...v1.25.0
[1.24.0]: https://github.com/andyko18/specops-ko/compare/v1.23.0...v1.24.0
[1.23.0]: https://github.com/andyko18/specops-ko/compare/v1.22.1...v1.23.0
[1.22.1]: https://github.com/andyko18/specops-ko/compare/v1.22.0...v1.22.1
[1.22.0]: https://github.com/andyko18/specops-ko/compare/v1.21.3...v1.22.0
[1.21.3]: https://github.com/andyko18/specops-ko/compare/v1.21.2...v1.21.3
[1.21.2]: https://github.com/andyko18/specops-ko/compare/v1.21.1...v1.21.2
[1.21.1]: https://github.com/andyko18/specops-ko/compare/v1.21.0...v1.21.1
[1.21.0]: https://github.com/andyko18/specops-ko/compare/v1.20.0...v1.21.0
[1.20.0]: https://github.com/andyko18/specops-ko/compare/v1.19.2...v1.20.0
[1.19.2]: https://github.com/andyko18/specops-ko/compare/v1.19.1...v1.19.2
[1.19.1]: https://github.com/andyko18/specops-ko/compare/v1.19.0...v1.19.1
[1.19.0]: https://github.com/andyko18/specops-ko/compare/v1.18.0...v1.19.0
[1.18.0]: https://github.com/andyko18/specops-ko/compare/v1.17.0...v1.18.0
[1.17.0]: https://github.com/andyko18/specops-ko/compare/v1.16.0...v1.17.0
[1.16.0]: https://github.com/andyko18/specops-ko/compare/v1.15.1...v1.16.0
[1.15.1]: https://github.com/andyko18/specops-ko/compare/v1.15.0...v1.15.1
[1.15.0]: https://github.com/andyko18/specops-ko/compare/v1.14.0...v1.15.0
[1.14.0]: https://github.com/andyko18/specops-ko/compare/v1.13.0...v1.14.0
[1.13.0]: https://github.com/andyko18/specops-ko/compare/v1.12.0...v1.13.0
[1.12.0]: https://github.com/andyko18/specops-ko/compare/v1.11.0...v1.12.0
[1.11.0]: https://github.com/andyko18/specops-ko/compare/v1.10.0...v1.11.0
[1.10.0]: https://github.com/andyko18/specops-ko/compare/v1.9.0...v1.10.0
[1.9.0]: https://github.com/andyko18/specops-ko/compare/v1.8.0...v1.9.0
[1.8.0]: https://github.com/andyko18/specops-ko/compare/v1.7.0...v1.8.0
[1.7.0]: https://github.com/andyko18/specops-ko/compare/v1.6.0...v1.7.0
[1.6.0]: https://github.com/andyko18/specops-ko/compare/v1.5.0...v1.6.0
[1.5.0]: https://github.com/andyko18/specops-ko/compare/v1.4.0...v1.5.0
[1.4.0]: https://github.com/andyko18/specops-ko/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/andyko18/specops-ko/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/andyko18/specops-ko/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/andyko18/specops-ko/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/andyko18/specops-ko/releases/tag/v1.0.0
