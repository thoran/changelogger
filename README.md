# changelogger

## Description

Given a directory of numbered revisions, writes a cumulative CHANGELOG into each of them.

It is for projects whose history was kept as numbered directories rather than as commits, and which have no CHANGELOG to show for it. Its output is a starting point to be edited, not a finished record: it can say what changed, but only you can say what the change was for.

For each revision in turn, `changelogger` takes the entry from the first of these tiers which applies:

1. The Changes section in the revision's script header, used as written.
2. A structural diff against the previous revision, listing the requires, modules, classes and methods added, removed or altered.
3. For the first revision, an inventory of what is present.

A revision which already has a CHANGELOG is skipped, so a generated entry can be rewritten by hand and will not be overwritten on a later run.


## Installation

### 0. Have a recent version of Ruby installed

### 1. Manually

```shell
git clone https://github.com/thoran/changelogger
cp ./changelogger/bin/changelogger to your preferred executable path
chmod +x /path/to/changelogger
```


## Usage

```shell
$ changelogger ~/path/to/revisions/root/
$ changelogger .
$ changelogger
```

The revisions root holds directories named `0`, `1`, `2` and so on, each a complete snapshot of the project at that point. Only numbered directories are considered; anything else is passed over. With no argument the current directory is used.


## The Changes section

Tier 1 reads the Changes section from the revision's script header, along with the version and date on the two bare comment lines above it:

```
#!/usr/bin/env ruby
# git-import-all

# 20260504
# 0.6.0

# Changes since 0.5:
# -/0:
# 1. ~ read_changelog(): Find the CHANGELOG in the highest numbered directory.
# 2. ~ main(): Parse the entries once.
```

The section is cumulative across one minor series and restarted at each new one, so that it cannot grow without bound. `Changes since 0.5:` names the previous minor version, without its patch number.

The `-/0:` and `n/n+1:` markers are the steps within that series. `-/0` is its first version, the dash standing for the absent predecessor; `1/2` is the step from its second version to its third. Items are numbered continuously across the whole section, so a later version's header carries the earlier steps with it and the marker says which step each item belongs to.

Only the last marker's items become the entry for that revision, the earlier ones having already been written into the entries of the revisions they belong to.

A `Discussion:`, `Notes:`, `Todo:` or `Examples:` heading ends the section.


## Output

Entries are written newest first, and each revision receives every entry up to and including its own, so revision `0` has one entry and the last revision has them all. The form is the one the repositories already use, and the one `git-import-all` reads, so the output needs no converting before an import — only the editing which any generated prose wants.

Where a revision's script header carries no date, a warning naming the revision goes to stderr and `## ????????` is written in its place, rather than a date being invented or the run stopped.

The version and date come from the revision's script header, which is the source of record:

```
# changelogger

# 20260422
# 0.2.0
```


## Related tools

`git-import-all` turns the same numbered revisions into a git repository, one commit per revision, taking each commit's message and date from the CHANGELOG. Running `changelogger` first is what makes that possible where no CHANGELOG exists.

`git-boot` creates the repository beforehand, beginning it with a parentless `.gitignore` commit so that real work is never the root.

`changelogger` is needed only where a CHANGELOG is missing. Once the history is in a repository, the CHANGELOG is written directly and neither tool is needed again.


## Bootstrapping

This repository's CHANGELOG was seeded by running `changelogger` over its own three revisions, then edited — which is the intended workflow. Tiers 1 and 3 both show in the result: 0.1.0 and 0.2.0 came from their Changes sections verbatim, while 0.0.0, having none, produced an inventory of all twenty-seven methods, which was replaced by a single line saying what the thing does.


## Contributing

1. Fork it: `https://github.com/thoran/changelogger/fork`
2. Create your feature branch: `git checkout -b my-new-feature`
3. Commit your changes: `git commit -am 'Add some feature'`
4. Push to the branch: `git push origin my-new-feature`
5. Create a new pull request


## License

MIT
