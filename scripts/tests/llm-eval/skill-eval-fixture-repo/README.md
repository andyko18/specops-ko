# skill-eval-fixture-repo

`run-skill-evals.sh` 가 질의마다 sandbox 에 복사·커밋하는 가짜 코드베이스다. 실행하지 않는다.

빈 sandbox 는 claude 가 system 컨텍스트의 git status 로 알아채 "파일 없음"으로 끝낸다 —
기존 코드를 전제하는 질의(`skills/*/trigger-queries.json`·`evals.json`)가 언급하는 파일을 여기 둔다.
질의를 추가해 새 파일명을 언급하면 이 디렉터리에도 파일을 추가한다. `.sh` 는 두지 않는다(CI shellcheck 대상).
