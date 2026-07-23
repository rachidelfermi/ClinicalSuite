# Configuration schemas

The schema TSVs are the reviewed public contract for Module 2:

- `clinical.conf.schema.tsv` defines every accepted configuration key, whether it
  is required, its type, default, and validation rule.
- `samples.tsv.schema.tsv` defines the fixed sample-manifest columns and rules.
- `reference_manifest.schema.tsv` and `database_manifest.schema.tsv` define the
  external-resource declarations consumed by preflight.

The Bash parser contains the corresponding executable validation rules. Tests
verify that both example files conform to these schemas. Unknown configuration
keys and unknown, duplicate, or missing manifest columns are rejected.
