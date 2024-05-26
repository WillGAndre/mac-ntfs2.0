#!/bin/bash

prompt_for_sudo() {
    sudo_password=$(osascript -e 'Tell application "System Events" to display dialog "Enter your password:" with hidden answer default answer ""' -e 'text returned of result')
    echo "$sudo_password"
}
run_with_sudo() {
    echo "$sudo_password" | sudo -S "$@"
}

load_env_file() {
    if [ -f "env" ]; then
        export $(cat "env" | sed 's/#.*//g' | xargs)
        echo "Partition Type: $part_type"
    else
        part_type="Microsoft Basic Data"
    fi
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

## Hard-check NTFS tools
check_ntfs_tools() {
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    export PATH="/usr/local/bin:/opt/homebrew/bin:$PATH"
    if ! command -v brew &> /dev/null; then
        echo "No brew!"
        exit 1
    fi
    brew install --cask macfuse
    brew install ntfs-3g
    brew install tree
}

load_env_file
ntfs_id=$(diskutil list | grep -E "$part_type" | awk '{print $NF}')
if [ -z "$ntfs_id" ]; then
    osascript -e 'display dialog "NTFS device not found" buttons {"OK"} default button "OK"'
    exit 1
fi
check_ntfs_tools
sudo_password=$(prompt_for_sudo)
if [ -z "$sudo_password" ]; then
    echo "No password entered. Exiting."
    exit 1
fi
mount_point="/Volumes/NTFS_$ntfs_id"
if [ ! -d "$mount_point" ]; then
    echo "$sudo_password" | sudo -S mkdir -p "$mount_point"
fi
ntfs_3g_output=$(echo "$sudo_password" | sudo -S ntfs-3g /dev/$ntfs_id $mount_point -olocal -oallow_other 2>&1)
ntfs_3g_status=$?
if [ $ntfs_3g_status -ne 0 ]; then
    echo "Mount Fail: $ntfs_3g_output"
fi

while true; do
    echo -e "\n\n\n\n\n\n\n\n\n\n\n\n"
    echo "Directory structure of $mount_point:"
    tree -u -h -D -L 1 $mount_point
    cmd=$(osascript -e 'choose from list {"uf - upload file(s)", "ud - upload dir(s)", "e - exit"} with prompt "Select an action:"' | tr -d ',')

    if [ "$cmd" = "e - exit" ]; then
        diskutil unmount $mount_point
        break
    elif [ "$cmd" = "uf - upload file(s)" ]; then
        files=$(select_files)
        if [ ! -z "$files" ]; then
            IFS=$'\n' read -rd '' -a file_array <<< "$files"
            for file in "${file_array[@]}"; do
                rsync "$file" "$mount_point"
                if [ $? -ne 0 ]; then
                    osascript -e 'display dialog "Failed to copy: '$file'" buttons {"OK"} default button "OK"'
                fi
            done
        fi
    elif [ "$cmd" = "ud - upload dir(s)" ]; then
        dirs=$(select_dirs)
        if [ ! -z "$dirs" ]; then
            IFS=$'\n' read -rd '' -a dir_array <<< "$dirs"
            for dir in "${dir_array[@]}"; do
                rsync -r "$dir" "$mount_point"
                if [ $? -ne 0 ]; then
                    osascript -e 'display dialog "Failed to copy: '$dir'" buttons {"OK"} default button "OK"'
                fi
            done
        fi
    fi
done
