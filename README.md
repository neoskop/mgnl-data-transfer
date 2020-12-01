# mgnl-data-transfer

Transfer data between different Magnolia instances.

## Components

- **Backup** is a sidecar container that will periodically create backups from
  a running Magnolia instance and upload it to an SFTP server
- **Restore** is an init container to bootstrap a Magnolia instance with a 
  backup from an SFTP server