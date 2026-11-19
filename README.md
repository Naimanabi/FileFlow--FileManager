# FileFlow

A lightweight, interactive command-line file manager written as a single Bash script. Items are listed as a numbered table, so you act on them by number instead of typing long file names. No dependencies beyond standard Unix tools.

## Features

- Numbered, sorted listing (folders first) with sizes
- Navigate, copy, move, rename, create files and folders
- Safe delete to a trash folder, plus permanent delete with confirmation
- Recursive, case-insensitive search
- Change permissions (octal or symbolic)
- Toggle hidden files
- Input validation; errors never crash the program

## Requirements

Bash and standard Unix utilities (`cp`, `mv`, `rm`, `find`, `du`, `stat`, `chmod`). The `permission` command uses GNU `stat`.

## Usage

```bash
git clone https://github.com/<your-username>/fileflow.git
cd fileflow
chmod +x fileflow.sh
./fileflow.sh [start_directory]
```

Type commands at the `>` prompt. `N` is the item number shown in the listing. Commands are not case-sensitive.

| Command | Description |
|---|---|
| `cd N` / `cd PATH` | Open folder N or jump to a path |
| `back` | Go to the parent folder |
| `copy N [DEST]` | Copy item N |
| `move N [DEST]` | Move item N |
| `rename N NEWNAME` | Rename item N |
| `delete N` | Move item N to the trash |
| `delete N -p` | Permanently delete item N |
| `make file NAME` | Create an empty file |
| `make folder NAME` | Create a folder |
| `search NAME` | Search here and below |
| `permission N MODE` | Change permissions, e.g. `permission 3 755` |
| `hidden` | Show or hide hidden files |
| `trash` | View the trash |
| `help` | Show the help screen |
| `quit` | Exit |

## Safety

- `delete N` moves items to `~/.fileflow_trash` with a timestamp, so they can be recovered by moving them back out.
- `delete N -p` asks for confirmation (`y` or `yes`).
- Copy/move asks before overwriting; rename never overwrites.

## Limitations

- Names or paths containing spaces can't be typed in most commands.
- There is no refresh command; `cd .` reloads the list.
