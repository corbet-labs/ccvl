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

Create one `applications/<job-id>/application.json` from
`templates/application.json` for every concrete opportunity. Do not maintain a
second Markdown copy of its tailored fields.

## Updating from ccvl

Keep personal changes in private commits. To import a new upstream release:

```sh
git fetch upstream
git merge --ff-only upstream/main
```

If private commits are already ahead, use a normal merge or a deliberate
rebase according to the repository's history policy. Never force-push a shared
private repository without reviewing the exact rewritten commits first.

## Publishing improvements

Reimplement or cherry-pick only generic changes into a clean ccvl checkout.
Run `bash ./ccvl public-check`, inspect every staged path, and confirm that the change
contains no applicant, target, application, recipient, or outcome data.
