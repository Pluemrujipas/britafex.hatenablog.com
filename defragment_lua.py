import re
import sys
from pathlib import Path


def sub_multiline(pattern, repl, text, flags=0):
    return re.sub(pattern, repl, text, flags=re.DOTALL | re.MULTILINE | flags)


def main(src_path, dst_path):
    code = Path(src_path).read_text(encoding="utf-8")

    # 1) Collapse named assignment via temp function variable:
    #    TargetName = Lxx_1
    #    function Lxx_1(args) ... end
    code = sub_multiline(
        r"""
(^|\n)
([A-Za-z_][\w\.\:]*)\s*=\s*(L\d+_1)\s*\n
function\s+\3\s*\(([^)]*)\)\s*\n
(.*?)\nend
""",
        r"\1function \2(\4)\n\5\nend",
        0,
    )

    # 2) Collapse method assignment on tables (explicit dot form)
    code = sub_multiline(
        r"""
(^|\n)
([A-Za-z_][\w]*)\.([A-Za-z_][\w]*)\s*=\s*(L\d+_1)\s*\n
function\s+\4\s*\(([^)]*)\)\s*\n
(.*?)\nend
""",
        r"\1function \2.\3(\5)\n\6\nend",
        0,
    )

    # 3) Collapse RegisterNUICallback temp wrappers
    code = sub_multiline(
        r"""
(^|\n)
(L\d+_1)\s*=\s*RegisterNUICallback\s*\n
(L\d+_1)\s*=\s*(".*?")\s*\n
function\s+(L\d+_1)\s*\(([^)]*)\)\s*\n
(.*?)\nend\s*\n
\2\(\3,\s*\5\)
""",
        r"\1RegisterNUICallback(\4, function(\6)\n\7\nend)",
        0,
    )

    # 4) Collapse AddEventHandler temp wrappers
    code = sub_multiline(
        r"""
(^|\n)
(L\d+_1)\s*=\s*AddEventHandler\s*\n
(L\d+_1)\s*=\s*(".*?")\s*\n
function\s+(L\d+_1)\s*\(([^)]*)\)\s*\n
(.*?)\nend\s*\n
\2\(\3,\s*\5\)
""",
        r"\1AddEventHandler(\4, function(\6)\n\7\nend)",
        0,
    )

    # 5) Collapse RegisterNetEvent temp wrappers -> RegisterNetEvent + AddEventHandler
    code = sub_multiline(
        r"""
(^|\n)
(L\d+_1)\s*=\s*RegisterNetEvent\s*\n
(L\d+_1)\s*=\s*(".*?")\s*\n
function\s+(L\d+_1)\s*\(([^)]*)\)\s*\n
(.*?)\nend\s*\n
\2\(\3,\s*\5\)
""",
        r"\1RegisterNetEvent(\4)\nAddEventHandler(\4, function(\6)\n\7\nend)",
        0,
    )

    # 6) Collapse CreateThread temp wrappers
    code = sub_multiline(
        r"""
(^|\n)
(L\d+_1)\s*=\s*CreateThread\s*\n
function\s+(L\d+_1)\s*\(\)\s*\n
(.*?)\nend\s*\n
\2\(\3\)
""",
        r"\1CreateThread(function()\n\4\nend)",
        0,
    )

    # 7) Collapse exports temp wrappers
    code = sub_multiline(
        r"""
(^|\n)
(L\d+_1)\s*=\s*exports\s*\n
(L\d+_1)\s*=\s*(".*?")\s*\n
function\s+(L\d+_1)\s*\(([^)]*)\)\s*\n
(.*?)\nend\s*\n
\2\(\3,\s*\5\)
""",
        r"\1exports(\4, function(\6)\n\7\nend)",
        0,
    )

    # 8) Generic single-arg call wrappers: F = SomeFunc; function G(...) ... end; F(G)
    code = sub_multiline(
        r"""
(^|\n)
(L\d+_1)\s*=\s*([A-Za-z_][\w]*)\s*\n
function\s+(L\d+_1)\s*\(([^)]*)\)\s*\n
(.*?)\nend\s*\n
\2\(\3\)
""",
        r"\1\3(function(\5)\n\6\nend)",
        0,
    )

    # 9) Remove trivial temp reassignments
    code = sub_multiline(
        r"""
(^|\n)
(L\d+_1)\s*=\s*(L\d+_1)\s*\n
""",
        r"\1",
        0,
    )

    Path(dst_path).write_text(code, encoding="utf-8")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python3 defragment_lua.py INPUT.lua OUTPUT.lua")
        sys.exit(1)
    main(sys.argv[1], sys.argv[2])

