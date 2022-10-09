# prj

This provides utilities for data analysis project tracking and backup.
It offers some basic functionality based on my opiniated balance between best practice and practicality.

Features are:
- simple logging functions to keep track of file changes
- incremental backups using GNU `tar`
- SHA256 based file integrity and difference tracking
- helpers for structuring projects and making notes
- helpers to automatically log code runs and changes
- basic file restoration facilities


Why on earth would you write something like this when XXX already exists?
I love git, and I think projects like [`git annex`](https://git-annex.branchable.com/) and [datalad](https://www.datalad.org/) have a lot going for them to incorporate large datasets into a `git`-like interface.
The problem is that it's never quite as easy as you want it to be, and when something goes wrong it can be confusing to revert or fix.
But the biggest problem is that in universities our institutional storage is all on NFS filesystems designed to be used on windows.
This causes lots of weird issues using `git annex` (links are now supported, but WSL2 doesn't connect to external drives in fully compatible ways yet).
I also really like the note taking that's integrated into `datalad`, but for most bioinformatics analyses the run-times are too high and the potential for errors are so numerous that I need some way of frankensteining the results together.

`prj` is not a fully featured version control system that can track multiple branches and merge distributed changes.
It is however fairly simple, hackable, broadly compatible with git code tracking, and everything is stored out in the open.
I can copy my files however I like without worrying whether XXX software is present on the other end, and if I want to copy intermediate results (that I don't intend to backup) that's ok too.

Anyway, all of this is to say, this stuff was written for the way that I want to work and I think it's a good compromise.


## Install

You'll need a couple of dependencies to this to work:

- GNU awk
- gnu coreutils
- python3
- bash >= 4

Most linux systems will be good to go, on a Mac/BSD you might need to figure it out.

You can just copy all of the above scripts somewhere on your path and go.
If you intend to hack it or pull down changes from here regularly, I suggest you just clone the git repo somewhere and add that to your path.
That's what I do, and I can just add new features etc as I need it.


## Important things to note

We track file changes using SHA256 sums, which can take a long time to compute (particularly for large files).
We use checksums because NFS filesystem modification times are generally pretty unreliable, and each filesystem stores them slightly differently.
We compute checksums in parallel to speed things up, but this will use all available CPUs and I haven't implemented a thread-limiting parameter yet. It's probably best not to run `prj-sha`, `prj-save`, `prj-diff`, or `prj-restore` on a supercomputer head node.


Any commands with the prefix `prj-private` **are not intended to be used by you**, they're helper scripts that are called by the other commands.
I'm using this system in lieu of some kind of library to keep the install and compatibility fairly simple.


## `prj` structure

The basic workflow is this.
After you initialise a project with `prj init`, you can start making changes.
You can add files using `prj add`, and the added files will be logged in the file `INPUTS.txt`.

You can add incremental notes to the file `NOTES.txt` using `prj note` (or just yourself).
`NOTES.txt` is a temporary place to store un-saved notes and commands that will later be saved to the `CHANGELOG.txt`.
Code can be run and automatically logged to `NOTES.txt` using `prj shell`, `prj run` and `prj sbatch`.

You can save a snapshot of the project using `prj save`.
This script will save any new or modified files to a gzipped tar-ball, in the `backups` folder.
Unchanged files that were in the previous backup are not stored in the new tarball, as they can be recovered from the previous one.
`prj save` will write a record of the files that are being backed up and add any notes from `NOTES.txt` to the `CHANGELOG.txt`, which will then be included in the backup tarball.
The `NOTES.txt` file is removed after it has been successfully added to the `CHANGELOG.txt`.


I suggest you store any intermediate data (that shouldn't be backed up) in `work`, and files that should be backed up in `output`.
Combined with `input` and the changelog this makes it pretty clear what has come from where.

I suggest you keep any code, scripts, git repos, etc in the `code` folder; and keep your environment config file(s) in the `envs` folder (e.g. conda yaml, dockerfiles, singularity templates).

Keep a separate log of the project from `CHANGELOG.txt`.
Basically, keep changelog as a way of tracking changes, and have a separate file e.g. README.md which includes the most recent version of code, results, and interpretation.
CHANGELOG tracks your projects history, the other file is the final output.
The other (e.g. README.md) file can of course be backed up, so previous reports can be recovered.

Note that nothing is preventing you from tracking code, CHANGELOG.txt, readmes etc using `git` as well as `prj`.
It may work well with some clever `.prjignore` and `.gitignore` configurations.

## `prj`

`prj` is organised under several subcommands.
Like `git` you can call the subcommand as `prj subcommand` or `prj-subcommand`.
The former just redirects to the latter.

```
# prj
USAGE: prj subcommand [options ...]

Valid subcommands:
- init
- add
- save
- restore
- note
- shell
- run
- sbatch
- diff
- sha
- help

To display this message use subcommand 'help' or --help.

For help with a specific command use --help e.g.:
prj init --help
```

## `prj-init`

`prj-ini` creates a new project.
More details to come.

```
# prj-init
usage: prj-init [-h] [--bkpdir BKPDIR] [--inputdir INPUTDIR]
                [--outputdir OUTPUTDIR] [--codedir CODEDIR] [--envdir ENVDIR]
                [--workdir WORKDIR] [-c CHANGELOG] [--notefile NOTEFILE]
                [--inputfile INPUTFILE] [--profile {project,backup}]
                [-m MESSAGE]
                [BASE]

positional arguments:
  BASE                  Which base directory to use

options:
  -h, --help            show this help message and exit
  --bkpdir BKPDIR       Where to store the backups
  --inputdir INPUTDIR   Where to store the inputs
  --outputdir OUTPUTDIR
                        Where to store the outputs
  --codedir CODEDIR     Where to store code
  --envdir ENVDIR       Where to store environments
  --workdir WORKDIR     Where to working data
  -c CHANGELOG, --changelog CHANGELOG
                        Where to store logs.
  --notefile NOTEFILE   Where to cache notes to be saved later.
  --inputfile INPUTFILE
                        Where to log the locations of inputs.
  --profile {project,backup}
                        Where to cache notes to be saved later.
  -m MESSAGE, --message MESSAGE
                        The message to save
```


## `prj-add`

A utility that copies a file into the project and logs the command and new files.
NOTE: This just identifies new and updated files using modification times and presence absence.
If you make changes using another program these will show up in the list here too.
Messages will be logged to a file called `INPUTS.txt`, which you can edit as you wish.

```
# prj-add

 NOTE: if your COMMAND includes flags (e.g. -L --verbose etc), you need to put -- between the prj-add commands and the copy commands.
usage: prj-add [-h] [-b BASE] [-f FILE] [-n] [-m MESSAGE]
               COMMAND [COMMAND ...]

positional arguments:
  COMMAND               The command to run to get the files.

options:
  -h, --help            show this help message and exit
  -b BASE, --base BASE  Which base directory to use
  -f FILE, --inputfile FILE
                        Where to log updates.
  -n, --noignore        Don't add the file(s) to '.prjignore'.
  -m MESSAGE, --message MESSAGE
                        A message to write.
```


## `prj-save`

Creates a snapshot of the current state.
An incremental tar backup will be saved to the backup folder, and it will log the changes and any notes to the CHANGELOG.
Note that like `datalad` we don't bother with staging changes to be made etc. You can control what you want to save using the `.prjignore` or by explicitly saying which files you want to save using the `TARGET` arguments.

```
# prj-save
usage: prj-save [-h] [-b BASE] [-m MESSAGE] [--all] [-p BACKUP] [TARGET ...]

positional arguments:
  TARGET                Only save these files

options:
  -h, --help            show this help message and exit
  -b BASE, --base BASE  Which base directory to use
  -m MESSAGE, --message MESSAGE
                        The message to save
  --all                 Save everything, not just the diffs
  -p BACKUP, --backup BACKUP
                        Which backup to compare to
```


## `prj-restore`

Restores files or complete snapshots from a backup.
By default it will confirm before overwriting or deleting any files.

Logs changes to `NOTES.txt`.


```
# prj-restore
usage: prj-restore [-h] [-b BASE] [-m MESSAGE] [-d] [-o OUTFILE] [-y]
                   BACKUP [TARGET ...]

positional arguments:
  BACKUP                The backup to restore files from
  TARGET                Only save these files

options:
  -h, --help            show this help message and exit
  -b BASE, --base BASE  Which base directory to use
  -m MESSAGE, --message MESSAGE
                        The message to save
  -d, --delete          Delete files as well as overwriting them. Disabled if
                        TARGET provided.
  -o OUTFILE, --outfile OUTFILE
                        Where to write the logs. Note this will always append
                        to existing files.
  -y, --yes             Don't confirm overwrites.
```


## `prj-find`

Find a file or all files that are present in a backup snapshot.
This is needed because we take incremental snapshots, so if a filename with the same checksum was present in a previous backup, we won't save it again.
This reduces space, but means that it can be hard to find where the actual file is for a given snapshot.

That's all this does, look through the tar-files to find where it is.


```
# prj-find
usage: prj-find [-h] [-b BASE] BACKUP [TARGET ...]

positional arguments:
  BACKUP                The backup to look for files in
  TARGET                Only look for the locations of these files, not the whole snapshot

options:
  -h, --help            show this help message and exit
  -b BASE, --base BASE  Which base directory to use
```


## `prj-note`

Logs a note with a datestamp to be saved with the next snapshot.
Note that the notes are written to a visible file (default: `NOTES.txt`), which can simply be edited if you want to fix something.

```
# prj-note
usage: prj-note [-h] [-b BASE] [-o OUTFILE] MESSAGE

positional arguments:
  MESSAGE               A message to write.

options:
  -h, --help            show this help message and exit
  -b BASE, --base BASE  Which base directory to use
  -o OUTFILE, --outfile OUTFILE
                        Where to write the logs. Note this will always append
                        to existing files.
```


## `prj-shell`

This drops you in an interactive shell (default: `bash`) which you can use to run whatever analysis.
It uses `script` to log anything you do, and saves the code and lists any modified files during the session to the note file.
We do some cleaning up of the `script` output, but it's never quite perfect so you may like to edit the `NOTES.txt` file.
NOTE: like `prj-add` this just identifies file changes using modification times and presence absence. If you make changes using another program these will show up in the list here too.


```
# prj-shell
usage: prj-shell [-h] [-b BASE] [-n] [-o OUTFILE] [-m MESSAGE] [SHELL]

positional arguments:
  SHELL                 What interactive command to run.

options:
  -h, --help            show this help message and exit
  -b BASE, --base BASE  Which base directory to use
  -n, --no-echo         Suppress stdout/stderr.
  -o OUTFILE, --outfile OUTFILE
                        Where to write the logs. Note this will always append
                        to existing files.
  -m MESSAGE, --message MESSAGE
                        A message to write.

NOTE: some shells (e.g. python) don't display anything if you use the --no-echo flag.
```


## `prj-run`

Not yet implemented, but it'll be a hybrid of `prj-shell` and `prj-add`.
Basically, run a command, log the command and outputs (optional), and note the file diffs.


## `prj-sbatch`

Not yet implemented, but it'll be `prj-run` for submitting slurm jobs.
Unsure how i'll update the logs, i think i'll inject some code into the sbatch script.


## `prj-diff`

Prints all file changes since your last backup.
NOTE: diffs are calculated based on SHA256 sums, so this may take a long time if you have big files.

```
# prj-diff
usage: prj-diff [-h] [-b BASE] [--all] [-p BACKUP] [-d DIR] [TARGET ...]

positional arguments:
  TARGET                Only check these files

options:
  -h, --help            show this help message and exit
  -b BASE, --base BASE  Which base directory to use
  --all                 Ignore the .prjignore
  -p BACKUP, --backup BACKUP
                        Which backup to compare to
  -d DIR, --dir DIR     Where to search for files
```


## `prj-sha`

Just prints SHA256 sums for everything in the project folder that isn't in the `.prjignore`.
Mostly used as an internal utility, but might be useful e.g. for checking integrity of non-backed up files after copying.


```
# prj-sha
usage: prj-sha [-h] [-b BASE] [--all] [-d DIR] [TARGET ...]

positional arguments:
  TARGET                Only check these files

options:
  -h, --help            show this help message and exit
  -b BASE, --base BASE  Which base directory to use
  --all                 Ignore the .prjignore
  -d DIR, --dir DIR     Where to search for file
```
