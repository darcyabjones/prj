# prj

This provides utilities for data analysis project tracking and backup.
It offers some basic functionality based on my personal balance of best practice and practicality.

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
[Borg](https://www.borgbackup.org/) is also a really cool project and addresses much of what `prj` does in a more elegant way.
The main reason for sticking with `tar` over Borg is future accessibility.
Borg may disappear in 5 years, but `tar` isn't going anywhere so we can still recover backups in the future.
If you just need a clever short-term backup system without all of the logging things then Borg is a great option.

`prj` is not a fully featured version control system that can track multiple branches and merge distributed changes.
It is however fairly simple, hackable, compatible with git, and everything is stored out in the open.
I can copy my files however I like without worrying whether XXX software is present on the other end, and if I want to copy intermediate results (that I don't intend to backup) that's ok too.

Anyway, all of this is to say, this stuff was written for the way that I want to work.
If it's something that you think you'd like to try or you have issues/ideas, then [create an issue on github](https://github.com/darcyabjones/prj/issues).


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
By default some tasks can run in parallel with 2 processes to speed things up.
You can increase performance of `prj-sha`, `prj-save`, `prj-diff`, or `prj-restore` by specifying `--cpus` (use a negative number to use all available cores).
Probably best not to do this on a supercomputer head note though :)


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
This script will save any new or modified files to a tarball, in the `backups` folder.
Unchanged files that were in a previous backup are not stored in the new tarball, as they can be recovered from the previous one.
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


## Backup system

The backups are stored in uncompressed `tar` files.
We compress individual files as we add them to the tarball. This makes listing files in the tarball faster, and means that we can skip compression of already compressed files.
The files are stored with their sha checksum as the filename, and any files that are compressed during backup will have an extension corresponding to the compression program.
We store the files as their checksums as it means we avoid adding duplicates, we don't get filename clashes.
The actual filenames for each `save` are stored as a standard checksum file (e.g. `sha256sum  filename`).
When you restore the file, it looks for the corresponding sha256 sums in the tar balls, and restores the file to the filename given a particular save snapshot (decompressing as necessary).

To avoid creating huge `.tar` files, we restrict the maximum size to `4GB` (can be changed in `.prj`).
This just helps when copying file, creating checksums before and after copying, and listing files within each tarball will also be faster.
The backup system will try to pack as much in to each tar file without exceeding the size limit. This means that files for a single snapshot may be spread over multiple tar files.
Files larger than the size limit will be alone in their own tar file.

To speed up finding files within the tar files, we also store a `MANIFEST` file which simply lists the contents.
This manifest can be regenerated using `prj remanifest *.tar`.

The snapshot checksum files are also stored in the tar-balls as plain text.
If for whatever reason you lose the `.sha256` files you can `tar --extract` them.
Note that the files corresponding to that snapshot file may be in a different tarball.


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
- remanifest
- find
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
                [--workdir WORKDIR] [--changelog CHANGELOG]
                [--notefile NOTEFILE] [--inputfile INPUTFILE]
                [--profile {project,backup}] [-c {gzip,bzip2,zstd}]
                [-l COMP_LEVEL] [-m MESSAGE]
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
  --changelog CHANGELOG
                        Where to store logs.
  --notefile NOTEFILE   Where to cache notes to be saved later.
  --inputfile INPUTFILE
                        Where to log the locations of inputs.
  --profile {project,backup}
                        Where to cache notes to be saved later.
  -c {gzip,bzip2,zstd}, --compression {gzip,bzip2,zstd}
                        Which compression algorithm to use when archiving
                        files. Note that these tools will be needed for future
                        decompression, so choose wisely.
  -l COMP_LEVEL, --compression-level COMP_LEVEL
                        Use this compression level instead of the program
                        default. Integer
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
usage: prj-save [-h] [-b BASE] [-m MESSAGE] [--all] [--cpus CPUS]
                [-c {global,gzip,bzip2,zstd}] [-l COMP_LEVEL]
                [--notefile NOTEFILE_] [--changelog CHANGELOG_]
                [--tmp THISTMPDIR] [--bkpdir BKPDIR]
                [TARGET ...]

positional arguments:
  TARGET                Only save these files

options:
  -h, --help            show this help message and exit
  -b BASE, --base BASE  Which base directory to use
  -m MESSAGE, --message MESSAGE
                        The message to save
  --all                 Save everything, not just the diffs
  --cpus CPUS           What's the maximum number of CPUs we can use? Use -1
                        for all.
  -c {global,gzip,bzip2,zstd}, --compression {global,gzip,bzip2,zstd}
                        Which compression algorithm to use when archiving
                        files. Note that these tools will be needed for future
                        decompression, so choose wisely.
  -l COMP_LEVEL, --compression_level COMP_LEVEL
                        Use this compression level instead of the program
                        default.
  --notefile NOTEFILE   Where to cache notes to be saved later.
  --changelog CHANGELOG
                        Where to store logs.
  --tmp TMPDIR          Where to store intermediate files. Default from TMPDIR
                        or working directory.
  --bkpdir BKPDIR       Which backup directory to use. Mandatory if you're not
                        in a prj project. If specified you probably want this
                        to be somewhere outside of your current working
                        directory (or --base) to avoid backing up previous
                        backups.
```


## `prj-restore`

Restores files or complete snapshots from a backup.
By default it will confirm before overwriting or deleting any files.

Logs changes to `NOTES.txt`.


```
# prj-restore
usage: prj-restore [-h] [-b BASE_] [-m MESSAGE] [-d] [--notefile NOTEFILE]
                   [-y] [--cpus CPUS] [--tmp TMPDIR]
                   BACKUP [TARGET ...]

positional arguments:
  BACKUP                The backup to restore files from. Use HEAD to restore
                        from latest save.
  TARGET                Only save these files

options:
  -h, --help            show this help message and exit
  -b BASE, --base BASE  Which base directory to use
  -m MESSAGE, --message MESSAGE
                        The message to save
  -d, --delete          Delete files as well as overwriting them. Disabled if
                        TARGET provided.
  --notefile NOTEFILE   Where to cache notes to be saved later.
  -y, --yes             Don't confirm overwrites.
  --cpus CPUS           What's the maximum number of CPUs we can use? Use -1
                        for all.
  --tmp TMPDIR          Where to store intermediate files. Default from TMPDIR
                        or working directory.
```

## `prj-remanifest`

```
# prj-remanifest
usage: prj-remanifest [-h] BACKUP [BACKUP ...]

positional arguments:
  BACKUP      The tarfiles to update the manifest for

options:
  -h, --help  show this help message and exit
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
  BACKUP                The backup to look for files in. Use HEAD to compare
                        with latest. Use ALL to show all locations of all
                        backup files.
  TARGET                Only look for the locations of these files, not the
                        whole snapshot

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

Using the `--no-echo` flag will avoid having odd output if you use tab expansion of up-arrows to find previous commands.
But this will also suppress any results (i.e. only log what you type).

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
usage: prj-diff [-h] [-b BASE] [--all] [--cpus CPUS] BACKUP [TARGET ...]

positional arguments:
  BACKUP                Which backup to compare to. Use HEAD to compare with
                        latest. Use ALL to show all tracked files in the
                        project.
  TARGET                Only check these files

options:
  -h, --help            show this help message and exit
  -b BASE, --base BASE  Which base directory to use
  --all                 Ignore the .prjignore
  --cpus CPUS           What's the maximum number of CPUs we can use? Use -1
                        for all.
```


## `prj-sha`

Just prints SHA256 sums for everything in the project folder that isn't in the `.prjignore`.
Mostly used as an internal utility, but might be useful e.g. for checking integrity of non-backed up files after copying.


```
# prj-sha
usage: prj-sha [-h] [-b BASE] [--all] [--cpus CPUS] [TARGET ...]

positional arguments:
  TARGET                Only check these files

options:
  -h, --help            show this help message and exit
  -b BASE, --base BASE  Which base directory to use
  --all                 Ignore the .prjignore
  --cpus CPUS           What's the maximum number of CPUs we can use? Use -1
                        for all.
```
