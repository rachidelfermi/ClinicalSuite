# Operations

Operational run instructions will be written as runtime modules become available.
At present, `run.sh --help` is the only successful entry-point operation; invoking
the pipeline without arguments reports that analysis is unavailable and exits 69.

No reference, database, container, or patient data should be placed under source
control. See the contracts in `references/`, `databases/`, and `containers/`.
