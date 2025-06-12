### Backing up openshift secrets

Required environment variables:
| Variable | Description | Example |
| ---------| ------------| --------|
| NAMESPACES | list of namespaces, separated by commas, to from which to backup secrets | `aab123,def456` |
| WORKSPACE_PATH | Path on the container onto which a working directory PVC will be mounted | `/workspace` |
| BACKUP_VOLUME_PATH | Path on the container onto which the backup volume will be mounted | `/backup` |
