# secure-packer-bootstrapper
Per-build credential bootstrap for Packer/Kickstart: generates a passphrase-protected SSH keypair and temporary build-user password (hashed for Kickstart), injects the public key + hash via Packer vars, and loads the private key into ssh-agent for Packer/Ansible.
