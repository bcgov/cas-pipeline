## Docker image: Backing up openshift secrets

This docker image packs the necessary tools and scripts to backup secrets from multiple namespaces in a kubernetes environment.

#### How it works:

1. Fetching all secrets
Given all permisions to the service account have been granted, the script fetches all the secrets from the namespaces provided, in base64 format, and saves them to a tar.gz archive
2. Logrotate
Logrotate is then run manually. Its statefile will be saved along with the secret backup archives to the BACKUP_VOLUME_PATH provided

#### Required environment variables:
| Variable | Description | Example |
| ---------| ------------| --------|
| NAMESPACES | list of namespaces, separated by commas, to from which to backup secrets | `aab123,def456` |
| WORKSPACE | Path on the container onto which a writable working directory PVC will be mounted | `/workspace` |
| BACKUP_VOLUME | Path on the container onto which the backup volume will be mounted | `/backup` |
| LOGROTATE_CONF_PATH | Path on the container where the logrotate.conf file will be mounted | `/logrotate.conf` |


