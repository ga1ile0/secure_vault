# Secure Vault

Secure Vault is a Bash script that allows you to securely encrypt and decrypt files and directories using strong encryption algorithms.

## Prerequisites

- **Perl 5**
- **Bash shell**
- **OpenSSL**
- **cpanm** (Perl module installer)
- **Carton** (Perl module dependency manager)

### Install OpenSSL Development Headers

Some Perl modules require OpenSSL development headers. Install them using:

- **On Debian/Ubuntu:**

  ```bash
  sudo apt-get install libssl-dev
  ```
- **On CentOS/RHEL:**
  ```
  sudo yum install openssl-devel
  ```
- **On macOS (using Homebrew):**
  ```bash
  brew install openssl
  ```

## Installation

### Install cpanminus and Carton

If you don't have cpanm and Carton installed, install them using the following commands:
```bash
# Install cpanminus
curl -L https://cpanmin.us | perl - --sudo App::cpanminus

# Install Carton
cpanm Carton
```

### Install Dependencies
Use Carton to install all the required Perl modules listed in the cpanfile:
```bash
# Install dependencies
carton install
```
This will install all the necessary modules locally in the local directory.

## Usage
### Encrypt a File
```bash
./secure_vault.sh --encrypt <file>
```
Replace <file> with the path to the file you want to encrypt.
### Decrypt a File
```bash
./secure_vault.sh --decrypt <file.enc>
```
Replace <file.enc> with the path to the encrypted file.

## Examples
### Encrypt a File
```bash
./secure_vault.sh --encrypt mydocument.txt
```

### Decrypt a File
```bash
./secure_vault.sh --decrypt mydocument.txt.enc
```

## Notes

- **Running with carton exec:** Ensure that you run the script using carton exec to use the locally installed modules.
- **Password Prompt:** The script will prompt you to enter and verify a password when encrypting or decrypting.
- **Encrypting Directories:** If you specify a directory to encrypt, the script will create a tar archive and then encrypt it.

## Troubleshooting

### OpenSSL Errors
If you encounter errors related to OpenSSL during the installation of Perl modules, ensure that the OpenSSL development headers are installed on your system.

### Module Installation Failures
If `carton install` fails, try installing the dependencies manually using cpanm:
```bash
cpanm --installdeps .
```
