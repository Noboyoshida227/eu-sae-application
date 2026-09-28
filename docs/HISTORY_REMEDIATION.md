# Required Git-history and release-asset remediation

## Status (27 Sep 2026)

- The package now lives in a new repository,
  <https://github.com/Noboyoshida227/eu-sae-application>, started on
  17 Sep 2026 with a fresh history. That history contains none of the
  literature PDFs and no country data (checked on 27 Sep 2026).
- The previous repository was made private and then deleted on 27 Sep 2026.
  Its history is kept offline by the maintainer.
- Older repositories or archives of the package that predate the fresh start
  may still hold copies of the literature PDFs or superseded example files.
  They must be made private or deleted, and their forks and mirrors reviewed.

The procedure below remains the reference if a repository's history ever has
to be rewritten.

Removing files from the working tree does not remove them from Git history.
Before the fresh start, the eight literature PDFs were retrievable from the old
repository's objects and tags and from the v5.1.0 source archive; that
repository was deleted on 27 Sep 2026. Copies elsewhere still need review (see
Status above).

The repository owner should coordinate the following with institutional IP,
records-management and repository administrators. These steps rewrite public
history and therefore are intentionally **not** executed by the candidate
builder.

1. Preserve an access-controlled evidentiary mirror and record the approved
   removal scope.
2. Notify collaborators that all commit IDs and affected tags will change and
   that old clones must not be pushed back.
3. Rewrite every branch and tag, for example with `git filter-repo --path
   'docs/guidance/literature' --invert-paths --force`, also removing any other
   specifically approved superseded binary paths.
4. Verify both `git log --all -- 'docs/guidance/literature'` and an all-object
   path/blob audit return no affected objects.
5. Force-push the rewritten branches and tags only after approval. Retire or
   replace the v5.1.0 GitHub release/tag and any separately uploaded archives.
6. Ask GitHub Support about cache/object purge where required, and review forks
   and mirrors; a force-push alone cannot recall existing downloads.
7. Re-clone into an empty directory, repeat the object audit, build the release
   there, and verify checksums before publication.
8. Establish one canonical tag convention and Git LFS or an approved document
   repository for future large binaries, with rights review before addition.

The folder built by `scripts/build_clean_release.R` contains no `.git` history;
its zip is the package published on GitHub Releases.
