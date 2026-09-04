# Create a private downstream

GitHub does not allow a private repository inside the fork network of a public
repository. Use a standalone private repository with shared Git history.

```sh
git clone https://github.com/corbet-labs/ccvl.git applications
cd applications
git remote rename origin upstream
gh repo create OWNER/applications --private
git remote add origin git@github.com:OWNER/applications.git
git push --set-upstream origin main
```

This is a private downstream in Git terms even though GitHub does not display
the “forked from” badge.

The clone temporarily contains the reference-only personal showcase under the
narrow replacement permission in
`LICENSES/LicenseRef-CCVL-Personal-Content.txt`. Keep the working repository
non-public while replacing the approved sources under `cvl/`, the signature
asset, public identifier manifest, and generated personal PDFs. The reusable
mechanism and neutral scaffolds may be modified under their separate licenses;
the showcase author's claims and wording may not be carried into another
person's application.

Keep the same domains as upstream: private user knowledge in `interview/`, the
approved general document in `cvl/`, and one keyed package at
`opportunities/<organisation-key>/<position-key>/` for every concrete job.
Create an opportunity with `ccvl new-opportunity`; do not maintain a second
Markdown copy of the tailored fields in `application.json`.

## Strict ownership policy

Keep a `ccvl-downstream.json` file in the downstream. It names the exact
upstream remote and the only paths the downstream may own. A personalised
downstream normally owns its policy, sync workflow, `interview/`, `cvl/`, and
`opportunities/`; `.agent/`, the root launchers, schemas, skills, tests, and
fixed layout contracts remain upstream-owned. Narrow this list when a
downstream intentionally keeps the public showcase unchanged.

Run the boundary gate after fetching upstream:

```sh
cargo run --locked -- downstream-check \
  --upstream-ref refs/remotes/upstream/main
```

The command fails if the downstream does not contain the fetched upstream
commit, if the configured remote differs, or if even one unlisted path differs.
There is no implicit exception.

## Updating from ccvl

Keep personal changes in private commits. To import a new upstream release:

```sh
git fetch upstream
git merge --no-edit upstream/main
```

Do not poll for unattended updates. Trigger a trusted workflow from each push
to the upstream default branch. It must merge the exact triggering commit,
enforce the ownership policy, run the complete deterministic document gate,
and push only the verified merge. A superseded event is a no-op; a conflict,
structural deviation, document failure, or ownership breach leaves the private
remote unchanged. `.github/workflows/downstream-sync.yml` provides the generic
workflow. The maintainer's self-hosted Crow workflow keeps private interview
and opportunity data off hosted runners.

Keep credentials in the workflow runner's repository-scoped secret store and
restrict them to the intended event. Never expose personal downstream content
or its derived logs to an untrusted runner.

If private commits are already ahead, use a normal merge. Reserve a deliberate
history rewrite for a one-time conversion, protect the former tip with a remote
tag first, and review the exact replacement tree before using
`--force-with-lease`.

## Publishing improvements

Reimplement or cherry-pick only generic changes into a clean ccvl checkout.
Run `public-check`, inspect every staged path, and confirm that the change
contains no interview evidence, company research, application, recipient, or
outcome data.
