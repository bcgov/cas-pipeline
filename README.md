[![CircleCI](https://circleci.com/gh/bcgov/cas-pipeline/tree/master.svg?style=svg)](https://circleci.com/gh/bcgov/cas-pipeline/tree/master)

![Lifecycle:Stable](https://img.shields.io/badge/Lifecycle-Stable-97ca00)

# cas-pipeline

A set of shell scripts, makefiles and a helm chart to help the Climate Action Secretariat team deploy applications to the OpenShift cluster.

## Intended usage

The Makefile in this repository has two main commands used to, respectively, grant access to the appropriate OpenShift namespaces, and to add common configuration items in said namespaces

### `make authorize`

*To be run anytime the CAS team members change, or new namespaces are added*

Loads the list of namespaces from the `.env` file (see [.env-example](), the actual `.env` file is stored in the teams password manager), reads the list of users present in the appropriate GitHub teams (see teams descriptions on GitHub), and create a `RoleBinding` object for each user/namespace pair.

This script first deletes the previously created `RoleBinding`s (identified by a label) and recreates them based on the GitHub teams membership, to ensure that previous team members access is revoked.

Because it temporarily revokes access for all team members, this needs to be run manually by one of the current members listed as technical lead on the [project registry](https://registry.developer.gov.bc.ca/), as they are also granted access via a `RoleBinding` created by the Platform Services team.

### `make provision`

Deploys the [`cas-provision` helm chart] to every namespace used by the team. This relies on a hidden `.values.yaml` file (stored in the team's password manager) and creates various objects such as:

- `deployer`, `linter` and `job-runner` roles following the [least privilege principle]. Those roles are only allowed to manage objects used in the CAS team's projects, and would need to be updated if new OpenShift object types were to be used (e.g. see [PR #53](https://github.com/bcgov/cas-pipeline/pull/53), when `horizontalpodautoscalers` were first used).
- secrets listing the namespace names of the various applications (which are randomly generated when provisions), providing easier referencing for developers, .i.e. an application can look at the `cas-namespaces` secret to refer to the namespace of other applications.
- a DockerHub registry credential
- a `SysdigTeam` object, which is a custom resource created by platform services to grant access to the Sysdig monitoring platform.
- various secrets containing credentials used by our applications
- Utilizing `gcp` (the Google Cloud Platform CLI), creates buckets for TF state for every namespace used by the team. Relies on a being authorized with a service account (credentials stored in the team's password manager) with storage permissions on the project.

### `make install_crunchy_monitoring`

Deploys the [`crunchy-monitoring` helm chart] to the namespace defined in the values file. This relies on a hidden `.crunchy-values.yaml` file (stored in the team's password manager).

- requires defining the CIIP_NAMESPACE_PREFIX variable

### `make lint_monitoring_chart`

Lints the [`crunchy-monitoring` helm chart]

- requires defining the CIIP_NAMESPACE_PREFIX variable


### Adding a namespace



## Deprecated things

Prior to using Helm to deploy applications to the OpenShift cluster, the CAS team used a set of common `make` commands (e.g. `configure`, `build`, `install`) that abstracted the `oc` command line tool. These came with various utility functions located in the `*.mk` files, which are still in use in some projects but are considered deprecated.

[least privilege principle]: https://csrc.nist.gov/glossary/term/least-privilege
