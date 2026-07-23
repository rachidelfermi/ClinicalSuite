# Container definitions

Each definition uses an immutable linux/amd64 OCI digest. Multi-stage definitions
copy only required runtimes between images. Downloaded upstream assets are
checksum-verified by `../build.sh` before Apptainer receives them through `%files`.

Definition `%test` sections are fail-fast. They provide an early build gate; the
separate `../validate.sh` suite remains the release gate and also verifies that
trained models and annotation data are absent.

Definitions contain packaging only. They do not contain pipeline commands,
scientific parameters, clinical thresholds, references, or databases.
