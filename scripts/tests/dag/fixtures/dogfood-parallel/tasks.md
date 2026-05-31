# dogfood-parallel fixture — 2 disjoint leaf DAG

DAG-AWARE PARALLEL dispatch harness 입력. T1·T2 는 outputs 가 disjoint 한
독립 leaf(depends_on=[]) 이므로 `dag::find_independent_batch` 가 [T1 T2] batch 를
형성 → implementing-ko L67-101 의 병렬 분기 자격을 충족한다.

## 의존 그래프

```yaml
tasks:
  - id: T1
    depends_on: []
    inputs: []
    outputs: [fileA.sh]
    ac: [AC-1]
  - id: T2
    depends_on: []
    inputs: []
    outputs: [fileB.sh]
    ac: [AC-2]
```
