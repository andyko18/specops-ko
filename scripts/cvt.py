#!/usr/bin/env python3
import sys
import json
import argparse

try:
    import yaml
except ImportError:
    print("DependencyError: pyyaml 미설치. pip install pyyaml", file=sys.stderr)
    sys.exit(1)


def main():
    parser = argparse.ArgumentParser(prog="cvt", description="JSON ↔ YAML 양방향 변환")
    parser.add_argument("--to", required=True, choices=["json", "yaml"],
                        help="출력 포맷")
    parser.add_argument("--indent", type=int, default=2,
                        help="JSON 출력 들여쓰기 (기본 2)")
    parser.add_argument("input", nargs="?", help="입력 파일 (생략 시 stdin)")
    args = parser.parse_args()

    if args.indent < 0:
        parser.error("--indent must be a non-negative integer")

    # 입력 읽기
    try:
        if args.input:
            with open(args.input, encoding="utf-8") as f:
                text = f.read()
        else:
            text = sys.stdin.read()
    except OSError as e:
        print(f"{type(e).__name__}: {args.input}", file=sys.stderr)
        sys.exit(1)
    except UnicodeDecodeError:
        print("ParseError: 입력이 UTF-8로 디코딩 불가", file=sys.stderr)
        sys.exit(1)

    # 빈 입력 → ParseError (JSON·YAML 양방향 공통)
    if not text.strip():
        print("ParseError: 빈 입력", file=sys.stderr)
        sys.exit(1)

    # Parse + Format
    try:
        if args.to == "yaml":
            data = json.loads(text)
            sys.stdout.write(yaml.dump(data, allow_unicode=True, default_flow_style=False))
        else:
            data = yaml.safe_load(text)
            print(json.dumps(data, indent=args.indent, ensure_ascii=False))
    except json.JSONDecodeError as e:
        print(f"ParseError: {e}", file=sys.stderr)
        sys.exit(1)
    except yaml.YAMLError as e:
        print(f"ParseError: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
