# secure_vault.sh
#!/bin/bash

# Configuration
PERL_SCRIPT_DIR="./perl"
KEY_DERIV_SCRIPT="${PERL_SCRIPT_DIR}/key_derivation.pl"
METADATA_SCRIPT="${PERL_SCRIPT_DIR}/metadata_handler.pl"

# Password handling
get_password() {
    local password=""
    local password2=""
    
    while true; do
        printf "\n"
        read -s -p "Enter password: " password
        read -s -p "Verify password: " password2
        
        if [ "$password" = "$password2" ]; then
            echo "$password"
            break
        else
            echo "Passwords don't match. Try again."
            printf "\n"
        fi
    done
}

# Directory handling
handle_directory() {
    local dir="$1"
    local operation="$2"
    local password="$3"

    case "$operation" in
        "encrypt")
            # Create tar archive with a consistent name
            local archive_name="${dir}.tar"
            tar -czf "$archive_name" "$dir"
            if [ $? -ne 0 ]; then
                echo "Error: Failed to create archive of directory."
                rm -f "$archive_name"
                exit 1
            fi

            # Encrypt the archive, suppress success message
            encrypt_file "$archive_name" "$password" "true"

            # Cleanup
            rm -f "$archive_name"
            rm -rf "$dir"
            echo "Success: Directory encrypted as '${archive_name}.enc'"
            ;;

        "decrypt")
            # Decrypt the archive, suppress success message
            decrypt_file "$dir" "$password" "" "true"

            # The decrypted archive name
            local archive_name="${dir%.enc}"

            # Extract the archive
            tar -xzf "$archive_name"
            if [ $? -ne 0 ]; then
                echo "Error: Failed to extract directory contents."
                rm -f "$archive_name"
                exit 1
            fi

            # Cleanup
            rm -f "$archive_name"
            echo "Success: Directory restored from archive"
            ;;
    esac
}

# Functions
encrypt_file() {
    local file="$1"
    local password="$2"
    local suppress_message="$3"

    # Start background task
    (
        # Store metadata
        perl "$METADATA_SCRIPT" --store "$file" "$password"
        if [ $? -ne 0 ]; then
            echo "Error: Failed to store metadata."
            exit 1
        fi
        # Derive key and IV
        local derived_key_hex=$(perl "$KEY_DERIV_SCRIPT" "$password" | xxd -p -c 256)
        local iv_hex=$(echo -n "$password" | sha256sum | awk '{print $1}' | head -c 32)
        # Encrypt file
        openssl enc -aes-256-cbc -salt -in "$file" -out "${file}.enc" -K "$derived_key_hex" -iv "$iv_hex"
        if [ $? -ne 0 ]; then
            echo "Error: Encryption failed."
            exit 1
        fi
        # Remove original file
        rm "$file"
    ) &
    pid=$!
    show_spinner $pid "Encrypting"
    wait $pid
    exit_status=$?
    if [ $exit_status -ne 0 ]; then
        exit $exit_status
    fi
    # Print success message unless suppressed
    if [ "$suppress_message" != "true" ]; then
        echo "Success: File encrypted successfully as '${file}.enc'"
    fi
}

decrypt_file() {
    local file="$1"
    local password="$2"
    local output_file="$3"
    local suppress_message="$4"
    local base_name="${file%.enc}"

    # Start background task
    (
        [ ! -f "${base_name}.meta" ] && echo "Error: Metadata file not found" && exit 1
        # Retrieve original file name
        local original_name=$(perl "$METADATA_SCRIPT" --retrieve "$base_name" "$password" 2>/dev/null)
        if [ $? -ne 0 ]; then
            echo "Error: Incorrect password."
            exit 1
        fi
        [ -z "$original_name" ] && echo "Error: Could not retrieve original filename" && exit 1
        # Derive key and IV
        local derived_key_hex=$(perl "$KEY_DERIV_SCRIPT" "$password" | xxd -p -c 256)
        local iv_hex=$(echo -n "$password" | sha256sum | awk '{print $1}' | head -c 32)
        # Decrypt file
        openssl enc -d -aes-256-cbc -in "$file" -out "${output_file:-$original_name}" -K "$derived_key_hex" -iv "$iv_hex"
        if [ $? -ne 0 ]; then
            echo "Error: Decryption failed."
            exit 1
        fi
        # Remove encrypted and metadata files
        rm "$file" "${base_name}.meta"
    ) &
    pid=$!
    show_spinner $pid "Decrypting"
    wait $pid
    exit_status=$?
    if [ $exit_status -ne 0 ]; then
        exit $exit_status
    fi
    # Print success message unless suppressed
    if [ "$suppress_message" != "true" ]; then
        echo "Success: File decrypted successfully as '${original_name}'"
        echo "Cleanup: Removed encrypted and metadata files."
    fi
}

show_spinner() {
    local pid=$1
    local message="$2"
    local spinner='-\|/'
    local delay=0.1
    printf "\n"
    while kill -0 $pid 2>/dev/null; do
        for i in $(seq 0 3); do
            printf "\r$message... ${spinner:$i:1}"
            sleep $delay
        done
    done
    printf "\r$message... Done.\n"
}

print_help() {
    echo "Secure Vault Usage:"
    echo
    echo "  $0 --encrypt <file>"
    echo "      Encrypts the specified <file> using a password."
    echo "      The encrypted file will have a .enc extension."
    echo
    echo "  $0 --decrypt <file.enc>"
    echo "      Decrypts the specified <file.enc> using a password."
    echo "      The original file will be restored."
    echo
    echo "  $0 --help"
    echo "      Displays this help message."
    echo
    echo "Examples:"
    echo "  Encrypt a file:"
    echo "      $0 --encrypt mydocument.txt"
    echo
    echo "  Decrypt a file:"
    echo "      $0 --decrypt mydocument.txt.enc"
    echo
}

# Main script
case "$1" in
    --encrypt)
        [ -z "$2" ] && echo "Error: No file specified" && exit 1
        [ ! -e "$2" ] && echo "Error: File not found" && exit 1
        password=$(get_password)
        if [ -d "$2" ]; then
            handle_directory "$2" "encrypt" "$password"
        else
            encrypt_file "$2" "$password"
        fi
        ;;
    --decrypt)
        [ -z "$2" ] && echo "Error: No file specified" && exit 1
        [ ! -f "$2" ] && echo "Error: Encrypted file not found" && exit 1
        password=$(get_password)
        if [[ "$2" == *.tar.enc ]]; then
            handle_directory "$2" "decrypt" "$password"
        else
            decrypt_file "$2" "$password"
        fi
        ;;
    -h)
        print_help
        ;;
    *)
        echo "Invalid option. Use -h for usage information."
        exit 1
        ;;
esac