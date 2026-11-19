#!/bin/bash
# Bash Command-Line File Manager
# Usage: ./fileflow.sh [start_directory]

TRASH_DIR="$HOME/.fileflow_trash"
SHOW_HIDDEN=0
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'
ITEM=""
ITEMS=()
MESSAGE=""

error()   { MESSAGE="Error: $1"; }
success() { MESSAGE="$1"; }
confirm() { local a; read -rp "$1 (y/n): " a; [[ "$a" =~ ^[Yy]([Ee][Ss])?$ ]]; }

get_item() {
    if [ -z "$1" ]; then
        error "Please give an item number, e.g. 'delete 2'."; return 1
    elif ! [[ "$1" =~ ^[0-9]+$ ]]; then
        error "'$1' is not a number."; return 1
    elif [ "$1" -lt 1 ] || [ "$1" -gt "${#ITEMS[@]}" ]; then
        error "Item $1 does not exist. Choose 1 to ${#ITEMS[@]}."; return 1
    fi
    ITEM="${ITEMS[$(($1 - 1))]}"
}

load_items() {
    local entry dirs=() files=()
    shopt -s nullglob
    [ "$SHOW_HIDDEN" -eq 1 ] && shopt -s dotglob
    for entry in *; do [ -d "$entry" ] && dirs+=("$entry") || files+=("$entry"); done
    shopt -u nullglob dotglob
    ITEMS=()
    while IFS= read -r entry; do [ -n "$entry" ] && ITEMS+=("$entry"); done \
        < <(printf '%s\n' "${dirs[@]}" | sort -f; printf '%s\n' "${files[@]}" | sort -f)
}

show_listing() {
    clear
    load_items
    echo -e "${BOLD}======================== FileFlow - File Manager ========================${NC}"
    echo -e " Current Directory: $(pwd)"
    echo -e "${BOLD}=========================================================================${NC}"

    local i item size width=20
    for item in "${ITEMS[@]}"; do
        [ $((${#item} + 2)) -gt "$width" ] && width=$((${#item} + 2))
    done
    width=$(( width * 5 / 3 ))
    printf " ${BOLD}%-5s %-${width}s  %s${NC}\n" "No." "Name" "Size"
    [ "${#ITEMS[@]}" -eq 0 ] && echo "   (this directory is empty)"

    for i in "${!ITEMS[@]}"; do
        item="${ITEMS[$i]}"
        if [ -d "$item" ]; then item="$item/"; size="-"; else size=$(du -h "$item" 2>/dev/null | cut -f1); fi
        printf " %-5s %-${width}s  %s\n" "$((i + 1))." "$item" "$size"
    done

    local S="  ${DIM}|${NC}  "
    echo -e "-------------------------------------------------------------------------"
    echo -e " ${BOLD}COMMANDS:${NC}  ${DIM}(commands are not case-sensitive)${NC}"
    echo -e " CD ${DIM}N${NC}${S}COPY ${DIM}N${NC}${S}MOVE ${DIM}N${NC}${S}RENAME ${DIM}N NAME${NC}${S}DELETE ${DIM}N${NC}${S}DELETE ${DIM}N${NC} -p"
    echo -e " MAKE file ${DIM}NAME${NC}${S}MAKE folder ${DIM}NAME${NC}${S}SEARCH ${DIM}NAME${NC}${S}PERMISSION ${DIM}N MODE${NC}"
    echo -e " BACK${S}TRASH${S}HELP${S}QUIT"
    echo -e " ${DIM}N = item number  |  type \`help\` for full reference  |  \`trash\` to view deleted files${NC}"
    [ -n "$MESSAGE" ] && { echo -e "\n $MESSAGE"; MESSAGE=""; }
    echo
}

show_help() {
    clear
    echo -e "${BOLD}============================== HELP ==============================${NC}"
    echo -e " Commands are not case-sensitive. ${DIM}N${NC} = the item number shown in the listing."
    local fmt=" ${BOLD}%-26s${NC} %s\n"

    echo -e "\n${BOLD} NAVIGATION${NC}"
    printf "$fmt" "cd N"                  "Open folder number N."
    printf "$fmt" "cd PATH"               "Jump to any path, e.g. 'cd /tmp' or 'cd ~'."
    printf "$fmt" "back  /  cd .."        "Go up to the parent folder."
    printf "$fmt" "hidden"                "Toggle showing hidden (dot) files."

    echo -e "\n${BOLD} FILE OPERATIONS${NC}"
    printf "$fmt" "copy N [DEST]"          "Copy item N to DEST. Asks for DEST if left out."
    printf "$fmt" "move N [DEST]"          "Move item N to DEST. Asks for DEST if left out."
    printf "$fmt" "rename N NEWNAME"       "Rename item N (it stays in the same folder)."
    printf "$fmt" "delete N"               "Send item N to the trash (can be restored)."
    printf "$fmt" "delete N -p"            "Erase item N for good (cannot be undone)."
    printf "$fmt" "make file NAME"         "Create a new empty file called NAME."
    printf "$fmt" "make folder NAME"       "Create a new folder called NAME."
    printf "$fmt" "permission N MODE"      "Change permissions, e.g. 'permission 3 755'."

    echo -e "\n${BOLD} FIND & RECOVER${NC}"
    printf "$fmt" "search NAME"            "Find files/folders here and below matching NAME."
    printf "$fmt" "trash"                  "View deleted files in the trash folder."

    echo -e "\n${BOLD} OTHER${NC}"
    printf "$fmt" "help"                   "Show this screen."
    printf "$fmt" "quit  /  exit"          "Leave the file manager."
    echo
    read -rp " Press Enter to go back..."
}

do_cd() {
    local target="${1:-$HOME}"
    if [[ "$target" =~ ^[0-9]+$ ]]; then
        get_item "$target" || return
        target="$ITEM"
        [ -d "$target" ] || { error "'$target' is a file, not a directory."; return; }
    fi
    target="${target/#\~/$HOME}"
    if [ ! -d "$target" ]; then
        error "'$target' is not a directory."
    elif [ ! -x "$target" ] || [ ! -r "$target" ]; then
        error "Permission denied: cannot open '$target'."
    else
        cd "$target" && success "Moved into $(pwd)"
    fi
}

do_transfer() {
    local action="$1" src dest="${3:-}" final
    local verb; [ "$action" = "cp" ] && verb="Copied" || verb="Moved"
    get_item "$2" || return
    src="$ITEM"
    [ -z "$dest" ] && read -rp "Destination path: " dest
    dest="${dest/#\~/$HOME}"
    [ -z "$dest" ] && { error "No destination given."; return; }

    final="$dest"
    [ -d "$dest" ] && final="$dest/$(basename "$src")"
    [ -e "$final" ] && { confirm "'$final' already exists. Overwrite?" || { MESSAGE="Cancelled."; return; }; }

    if [ "$action" = "cp" ]; then cp -r -- "$src" "$dest" 2>/dev/null
    else mv -- "$src" "$dest" 2>/dev/null; fi
    [ $? -eq 0 ] && success "$verb '$src' to '$dest'." \
                 || error "Could not process '$src' (check the path and permissions)."
}

do_rename() {
    local new="${2:-}"
    get_item "$1" || return
    [ -z "$new" ] && read -rp "New name for '$ITEM': " new
    if [ -z "$new" ]; then error "No new name given."
    elif [[ "$new" == */* ]]; then error "A name cannot contain '/'. Use 'move' to relocate an item."
    elif [ "$new" = "." ] || [ "$new" = ".." ]; then error "'$new' is not a valid name."
    elif [ "$new" = "$ITEM" ]; then error "The new name is the same as the current name."
    elif [ -e "$new" ] && ! [ "$new" -ef "$ITEM" ]; then error "'$new' already exists."
    elif mv -- "$ITEM" "$new" 2>/dev/null; then success "Renamed '$ITEM' to '$new'."
    else error "Could not rename '$ITEM' (check permissions)."; fi
}

do_delete() {
    local opt="${2:-}"
    [ "$opt" = "-P" ] && opt="-p"
    [ -n "$opt" ] && [ "$opt" != "-p" ] && { error "Unknown option '$opt'. Use 'delete N -p' to delete permanently."; return; }
    get_item "$1" || return
    if [ "$opt" = "-p" ]; then
        echo "WARNING: '$ITEM' will be permanently deleted and cannot be recovered."
        [ -d "$ITEM" ] && echo "It is a directory containing $(find "$ITEM" | wc -l) item(s) including itself."
        confirm "Are you sure?" || { MESSAGE="Permanent delete cancelled."; return; }
        rm -rf -- "$ITEM" 2>/dev/null && [ ! -e "$ITEM" ] && success "'$ITEM' permanently deleted." \
            || error "Could not delete '$ITEM' (permission denied?)."
    else
        mkdir -p "$TRASH_DIR" 2>/dev/null
        mv -- "$ITEM" "$TRASH_DIR/${ITEM}_$(date +%Y%m%d%H%M%S)" 2>/dev/null && success "'$ITEM' moved to trash ($TRASH_DIR)." \
            || error "Could not delete '$ITEM' (permission denied?)."
    fi
}

make_file() {
    local name="$1"; [ -z "$name" ] && { error "Usage: make file FILENAME — no name given."; return; }
    if [ -e "$name" ]; then error "'$name' already exists."
    elif touch -- "$name" 2>/dev/null; then success "File '$name' created."
    else error "Could not create file '$name' (check permissions)."; fi
}

make_folder() {
    local name="$1"; [ -z "$name" ] && { error "Usage: make folder FOLDERNAME — no name given."; return; }
    if [ -e "$name" ]; then error "'$name' already exists."
    elif mkdir -- "$name" 2>/dev/null; then success "Folder '$name' created."
    else error "Could not create folder '$name' (check permissions)."; fi
}

do_make() {
    case "$(echo "$1" | tr '[:upper:]' '[:lower:]')" in
        file|f)           make_file "$2" ;;
        folder|dir|d)     make_folder "$2" ;;
        "")               error "Usage: make file FILENAME  or  make folder FOLDERNAME" ;;
        *)                error "Unknown type '$1'. Use 'file' or 'folder'." ;;
    esac
}

do_search() {
    local pattern="${1:-}" count=0 path
    [ -z "$pattern" ] && read -rp "Search for: " pattern
    [ -z "$pattern" ] && { error "Search text cannot be empty."; return; }

    clear
    echo -e "${BOLD}Search results for '$pattern' in $(pwd)${NC}"
    echo "--------------------------------------------------------------"
    while IFS= read -r path; do
        count=$((count + 1))
        [ -d "$path" ] && echo " $count. ${path#./}/" || echo " $count. ${path#./}"
    done < <(find . -mindepth 1 -iname "*$pattern*" 2>/dev/null | sort)
    echo "--------------------------------------------------------------"
    [ "$count" -eq 0 ] && echo " No matches found." || echo " $count match(es) found."
    echo
    read -rp " Press Enter to go back..."
}

do_permission() {
    local mode="${2:-}"
    get_item "$1" || return
    if [ -z "$mode" ]; then
        echo "Current permissions of '$ITEM': $(stat -c '%A (%a)' "$ITEM")"
        read -rp "New mode (e.g. 755, 644, u+x, go-w): " mode
    fi
    if ! [[ "$mode" =~ ^[0-7]{3,4}$ || "$mode" =~ ^[ugoa]*[+=-][rwxXst]*(,[ugoa]*[+=-][rwxXst]*)*$ ]]; then
        error "Invalid mode '$mode'. Use octal (e.g. 755) or symbolic (e.g. u+x)."
    elif chmod "$mode" -- "$ITEM" 2>/dev/null; then
        success "Permissions of '$ITEM' are now $(stat -c '%A (%a)' "$ITEM")."
    else
        error "Could not change permissions (you may not own '$ITEM')."
    fi
}

do_trash() {
    clear
    echo -e "${BOLD}Trash: $TRASH_DIR${NC}"
    echo "--------------------------------------------------------------"
    if [ -n "$(ls -A "$TRASH_DIR" 2>/dev/null)" ]; then
        ls -lhA "$TRASH_DIR" | tail -n +2
        echo -e "\n To restore, run:  cd $TRASH_DIR  and use 'move N <path>'."
    else
        echo " The trash is empty."
    fi
    echo
    read -rp " Press Enter to go back..."
}

trap 'echo; MESSAGE="Use the quit command to exit."' INT

[ -n "$1" ] && { cd "$1" 2>/dev/null || { echo "Cannot open '$1'. Starting in $(pwd)."; sleep 1; }; }

while true; do
    show_listing
    read -rp " > " cmd arg1 arg2 arg3 || { echo; break; }
    cmd=$(echo "$cmd" | tr '[:upper:]' '[:lower:]')

    case "$cmd" in
        cd|open)                  do_cd "$arg1" ;;
        back|..)                  do_cd ".." ;;
        copy|cp)                  do_transfer cp "$arg1" "$arg2" ;;
        move|mv)                  do_transfer mv "$arg1" "$arg2" ;;
        rename|ren)               do_rename "$arg1" "$arg2${arg3:+ $arg3}" ;;
        delete|del)               do_delete "$arg1" "$arg2" ;;
        mkdir|make|mk|new)        do_make "$arg1" "$arg2" ;;
        search|find)              do_search "$arg1${arg2:+ $arg2}" ;;
        permission|permissions)   do_permission "$arg1" "$arg2" ;;
        hidden)
            SHOW_HIDDEN=$((1 - SHOW_HIDDEN))
            [ "$SHOW_HIDDEN" -eq 1 ] && success "Hidden files shown." || success "Hidden files hidden." ;;
        trash)                    do_trash ;;
        help|h)                   show_help ;;
        "")                       ;;
        quit|exit|q)              echo "Goodbye!"; exit 0 ;;
        *)                        error "Unknown command '$cmd'. Type 'help' to see all commands." ;;
    esac
done