# DarkPAN::Utils 1.0.0 Release Notes

**Released:** Mon Apr 13 2026  
**Author:** Rob Lauer &lt;rclauer@gmail.com&gt;

---

## Overview

Version 1.0.0 is a significant overhaul of `DarkPAN::Utils` and
`DarkPAN::Utils::Docs`. The headline change is the replacement of
`LWP::UserAgent` with the core `HTTP::Tiny`, reducing the dependency
footprint for Lambda deployments. Several correctness bugs are fixed,
both modules gain full POD documentation, and the build system is
replaced with the `CPAN::Maker::Bootstrapper` infrastructure.

---

## DarkPAN::Utils

### Breaking Changes

- **`parse_distribution_path`**: The regex no longer requires the
  `D/DU/DUMMY/` prefix. It now accepts bare filenames, absolute local
  paths, and CPAN author paths interchangeably. Callers that relied on
  the old behaviour of returning an empty list for non-`D/DU/DUMMY/`
  paths will see results where they previously did not.

### Bug Fixes

- **`_create_module_index`: old distribution versions now correctly
  evicted.** The version-tracking logic compared versions but always
  deleted the *new* zip rather than the old one, leaving all historical
  versions of a module in the index. A `%module_zip` tracker is
  introduced so that when a newer version is encountered the correct
  stale entry is removed.

- **`extract_module`: path-stripping regex fixed.** The substitution
  previously used a two-capture pattern with `$1`, which yielded the
  path *prefix* rather than the package directory name. The regex is
  now a single-capture form (`s{(?:.*\/)?([^\/]+)[.]tar[.]gz$}{$1}`)
  that works correctly for all path formats.

- **`fetch_package`: undef logger no longer fatal.** When
  `DarkPAN::Utils` is constructed with only `package => $tar` (no
  `init_logger` call), `$logger` is undef and the debug call would
  die. The call is now guarded with `if ($logger)`.

### New Features

- **`base_url` is now optional when `package` is provided.** Constructing
  with `package => $archive_tar_object` no longer requires `base_url`.
  The required/optional state of the attribute is scoped via `local`
  inside `new()` so it does not leak between instances.

- **`HTTP::Tiny` replaces `LWP::UserAgent`.** Both `fetch_darkpan_index`
  and `fetch_package` now use `HTTP::Tiny`. The response is a plain
  hashref (`$rsp->{success}`, `$rsp->{content}`). `HTTP::Request` and
  `LWP::UserAgent` are removed from the codebase and from `requires`.
  `IO::Socket::SSL` and `Net::SSLeay` are added as explicit prerequisites
  to support `https://` URLs.

- **`$PACKAGES_DETAILS` constant added.** The literal string
  `'02packages.details.txt.gz'` is now a named `Readonly` constant.

- **`$TRUE` / `$FALSE` constants added** and used throughout for
  attribute required/optional flags.

- **Full POD documentation added**, covering the constructor, all
  public methods, all attributes, and command-line options. `README.md`
  is regenerated from the new POD.

---

## DarkPAN::Utils::Docs

### Bug Fixes

- **`new()` now stores the normalised text.** When `text` was supplied
  as a filehandle or scalar reference, the normalised string was
  computed but never written back via `set_text`. Subsequent calls to
  `get_text` (including inside `parse_pod`) would return the original
  un-normalised value. Fixed with `$self->set_text($text)` before
  `parse_pod` is called.

- **`parse_pod` now uses the accessor.** Direct hash access
  (`$self->{text}`) replaced with `$self->get_text`, consistent with
  the rest of the class and required for the `set_text` fix above to
  take effect.

### Removals

- **`Pod::Markdown` removed.** Was imported but never used; removed
  from both the `use` list and `requires`.

### Other Changes

- **`IO::Scalar` added to `use` list.** Was used in `parse_pod` but
  not declared.

- **`Pod::Extract` now imported explicitly** (`qw(extract_pod)`) rather
  than relying on the default export.

- **`Readonly` added** with `$TRUE`/`$FALSE` constants for attribute
  flags.

- **`=encoding utf8` added to POD** to satisfy `Pod::Checker` when
  non-ASCII characters appear in the documentation.

- **Full POD documentation added** covering the constructor, all
  attributes, and all public methods.

---

## Build System

The `Makefile` has been replaced with the standard
`CPAN::Maker::Bootstrapper` build infrastructure.

- **Source files moved to `.pm.in` templates.** Version and module name
  are substituted at build time via `@PACKAGE_VERSION@` and
  `@MODULE_NAME@` placeholders. The `make POD=extract` and
  `make POD=remove` targets allow POD to be split into separate
  `.pod` files or stripped from the installed `.pm`.

- **`VERSION` file added** as the single source of truth for the
  version number.

- **`version.mk` added** with `make release`, `make minor`, and
  `make major` targets for semantic version bumping.

- **`release-notes.mk` added** to generate release artifacts (diff,
  file list, tarball) from git tags.

- **Automatic dependency scanning** via `scandeps-static.pl` with
  preserved/skip list support.

- **`t/00-darkpan-utils.t` added** as a basic smoke test.

- **`bin/darkpan-doc.pl` removed.** The old monolithic script that
  contained inline copies of `DarkPAN::Module::Docs` and an earlier
  version of `DarkPAN::Utils` is no longer needed.

---

## Dependency Changes

| Module                    | Change             |
|---------------------------|--------------------|
| `HTTP::Request`           | Removed            |
| `LWP::UserAgent`          | Removed            |
| `Pod::Markdown`           | Removed            |
| `HTTP::Tiny`              | Added (≥ 0.088)    |
| `IO::Socket::SSL`         | Added              |
| `Net::SSLeay`             | Added              |
| `List::Util`              | Added (explicit)   |
| `Log::Log4perl::Level`    | Added (explicit)   |
