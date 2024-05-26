#!/bin/bash

load_env_file() {
    if [ -f ".env" ]; then
        export $(cat ".env" | sed 's/#.*//g' | xargs)
    else
        dlist=$(diskutil list)
        echo "$dlist"
        part_type="Microsoft Basic Data"
    fi
    echo """
(Partition Type) part_type: Microsoft Basic Data
"""
}

select_files() {
    osascript <<EOF
    set selectedFiles to choose file with prompt "Select files to upload:" with multiple selections allowed
    set selectedPaths to {}
    repeat with selectedFile in selectedFiles
        set end of selectedPaths to POSIX path of selectedFile
    end repeat
    return selectedPaths
EOF
}
select_dirs() {
    osascript <<EOF
    set selectedFolders to choose folder with prompt "Select directories to upload:" with multiple selections allowed
    set selectedPaths to {}
    repeat with selectedFolder in selectedFolders
        set end of selectedPaths to POSIX path of selectedFolder
    end repeat
    return selectedPaths
EOF
}

check_ntfs_tools() {
    if ! command -v brew &> /dev/null; then
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    brews=$(brew list)
    if ! echo "$brews" | grep -q macfuse; then
        brew install --cask macfuse
    fi
    if ! echo "$brews" | grep -q ntfs-3g; then
        brew install ntfs-3g
    fi
    if ! echo "$brews" | grep -q tree; then
        brew install tree
    fi
}

load_env_file
ntfs_id=$(diskutil list | grep -E "$part_type" | awk '{print $NF}')
if [ -z "$ntfs_id" ]; then
    echo "NTFS device not found"
    exit 1
fi
check_ntfs_tools
mount_point="/Volumes/NTFS_$ntfs_id"
if [ ! -d "$mount_point" ]; then
    sudo mkdir -p "$mount_point"
fi
sudo ntfs-3g /dev/$ntfs_id $mount_point -olocal -oallow_other
while true; do
    clear
    tree -u -h -D -L 1 $mount_point
    echo """
uf - upload file(s)
ud - upload dir(s)
e  - exit
"""
    echo -e "\n"
    read -p "> " cmd
    if [ "$cmd" = "exit" ] || [ "$cmd" = "e" ]; then
        diskutil unmount $mount_point
        break
    elif [ "$cmd" = "uf" ]; then
        files=$(select_files)
        if [ ! -z "$files" ]; then
            IFS=$'\n' read -rd '' -a file_array <<< "$files"
            for file in "${file_array[@]}"; do
                rsync "$file" "$mount_point"
                if [ $? -ne 0 ]; then
                    echo "Failed to copy: $file"
                fi
            done
        fi
    elif [ "$cmd" = "ud" ]; then
        dirs=$(select_dirs)
        if [ ! -z "$dirs" ]; then
            IFS=$'\n' read -rd '' -a dir_array <<< "$dirs"
            for dir in "${dir_array[@]}"; do
                rsync -r "$dir" "$mount_point"
                if [ $? -ne 0 ]; then
                    echo "Failed to copy: $dir"
                fi
            done
        fi
    fi
done