# Module 5 preflight validation

Module 5 is validation-only. It downloads nothing, rebuilds no container, and
starts no scientific workflow.

## Validation commands

```bash
find . -type f -name '*.sh' -print0 | sort -z | xargs -0 bash -n
shellcheck -x -P "$PWD" bin/preflight.sh run.sh \
  tests/helpers/preflight_fixture.sh tests/unit/test_preflight.sh \
  tests/integration/test_preflight.sh tests/smoke/test_preflight.sh
bash tests/unit/test_preflight.sh
bash tests/integration/test_preflight.sh
bash tests/smoke/test_preflight.sh
bash tests/unit/test_configuration.sh
bash tests/smoke/test_configuration_system.sh
bash tests/unit/test_common.sh
bash tests/integration/test_configuration_common.sh
bash tests/smoke/test_common_library.sh
bash tests/unit/test_run_interface.sh
bash tests/unit/test_container_build.sh
bash tests/smoke/test_repository_skeleton.sh
bash tests/smoke/test_container_system.sh
git diff --check
```

ShellCheck 0.8.0 is unpacked temporarily because it is not installed system-wide.
The real-container smoke test validates all seven approved local SIFs with
networking disabled and a synthetic WES fixture.

## Result

Validated on 2026-07-23. Repository-wide Bash syntax, Module 5 ShellCheck,
preflight unit/integration/real-container smoke tests, Modules 1–4 regression
tests, JSON parsing, and `git diff --check` passed. The working tree was
intentionally left uncommitted.
