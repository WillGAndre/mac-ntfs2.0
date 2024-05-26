# mac-ntfs2.0
<pre>
[root     4.0K May 26 01:26]  /Volumes/NTFS_XXXX
├── [root     4.0K May 21 23:17]  The Sopranos
└── [root      196 May 25 02:17]  buyme

4 directories, 2 files

uf - upload file(s)
ud - upload dir(s)
e  - exit



> e
Volume XXXX XXXX on XXXX unmounted
</pre>

Read and write access for `NTFS` / `Microsoft Basic Data` partition types for mac OS.

<u>Requirement:</u> `brew` must be installed on host to run. `System Extensions` must be allowed for developer `Benjamin Fleischer` (<i>i.e.:</i> macFUSE is signed by "Benjamin Fleischer"), host restart is required on first run.

#### Quick-brew:
<pre>
brew install --cask macfuse
brew tap gromgit/homebrew-fuse
brew install ntfs-3g-mac
brew install tree
</pre>

1. Optionally create `env` file with target partition type.
2. `./ntfs.sh`

## [Platypus](https://sveinbjorn.org/platypus) Build
- `app/env` can be included to specify the partition type to be mounted.