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
the "forked from" badge.

The clone temporarily contains the reference-only personal showcase under the
narrow replacement permission in
`LICENSES/LicenseRef-CCVL-Personal-Content.txt`. Keep the working repository
non-public while replacing `cvl/general/`, the signature asset, the public
identifier manifest, and generated personal PDFs. The reusable code and neutral
templates may be modified under their separate licenses; the showcase author's
claims and wording may not be carried into another person's application.

Keep the same three top-level working groups as upstream: the general master in
`cvl/`, durable market work in `targets/`, and one keyed package at
`opportunities/<organisation-key>/<position-key>/` for every concrete role.
Create its `application.json` from `templates/application.json`; do not
maintain a second Markdown copy of its tailored fields.

## Strict ownership policy

Keep a `ccvl-downstream.json` file in the downstream. It names the exact
upstream remote and the only paths the downstream may own. Julian's private
`applications` repository deliberately permits only its policy, automatic-sync
workflow, `targets/`, and `opportunities/`; the general CV, document engine,
schemas, skills, tests, and fixed layout contracts remain upstream-owned.

Run the boundary gate after fetching upstream:

```sh
cargo run --locked -- downstream-check \
  --upstream-ref refs/remotes/upstream/main
```

The command fails if the downstream does not contain the fetched upstream
commit, if the configured remote differs, or if even one unlisted path differs.
There is no implicit exception or compatibility fallback.

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
GitHub workflow, while the maintainer's self-hosted Crow workflow keeps private
target and opportunity data off hosted runners.

If private commits are already ahead, use a normal merge. Reserve a deliberate
history rewrite for the one-time conversion of an existing standalone
repository, protect the former tip with a remote tag first, and review the
exact replacement tree before using `--force-with-lease`.

## Publishing improvements

Reimplement or cherry-pick only generic changes into a clean ccvl checkout.
Run the platform `public-check` command, inspect every staged path, and confirm
that the change contains no applicant, target, application, recipient, or
outcome data.
