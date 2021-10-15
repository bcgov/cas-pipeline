[![CircleCI](https://circleci.com/gh/bcgov/cas-pipeline/tree/master.svg?style=svg)](https://circleci.com/gh/bcgov/cas-pipeline/tree/master)

![Lifecycle:Stable](https://img.shields.io/badge/Lifecycle-Stable-97ca00)

# cas-pipeline

A collection of make functions used to compose pipelines
Examples of [standard targets] and usage to be added shortly.

## background

[Pathfinder] projects follow specific patterns when deploying to [OCP]
which are common to all projects on the cluster.

For instance:

- each project receives four [k8s namespaces]:
  - tools
  - dev
  - test
  - prod
- images should always be built in the tools namespace
- images should always be tagged to other namespaces
- tags should be structured to enable rapid deployment rollback
- configuration should be stored as code
- service accounts should be used to limit processes cluster access

...among other patterns.

This project provides a deployment abstraction layer for all
Climate Action Secretariat projects.

## usage

This project is intented to be added as a [submodule] to other
Climate Action Secretariat projects.

The preferred name of the submodule folder is `.pipeline`:

```
git submodule add https://github.com/bcgov/cas-pipeline.git .pipeline
```

For help, please visit [#cas] on [public team chat].

## Roles and service accounts

This project contains roles definitions for the CircleCI and Shipit service accounts used by other CAS projects.
The intent behind creating those custom roles is to follow the [least privilege principle].
Using the `make authorize` command, those roles and service accounts can be updated in the CAS [Pathfinder] projects .

## related

- [openshift-developer-tools](https://github.com/BCDevOps/openshift-developer-tools/tree/master/bin)
- [bcdk](https://github.com/BCDevOps/bcdk/tree/release/0.0.1)
- [extended-oc](https://github.com/bcgov/esm-server/blob/dev/openshift/templates/lib/extended-oc.sh)
- [mds/pipeline](https://github.com/bcgov/mds/tree/develop/pipeline)
- [tfrs/readme](https://github.com/bcgov/tfrs/blob/master/openshift/templates/components/README.md)
- [gwells/scripts](https://github.com/bcgov/gwells/tree/release/openshift/scripts)

[standard targets]: https://www.gnu.org/software/make/manual/html_node/Standard-Targets.html
[pathfinder]: https://developer.gov.bc.ca/What-is-Pathfinder
[ocp]: https://www.openshift.com/products/container-platform
[k8s namespaces]: https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/
[submodule]: https://git-scm.com/book/en/v2/Git-Tools-Submodules
[#cas]: https://chat.pathfinder.gov.bc.ca/channel/cas
[public team chat]: https://developer.gov.bc.ca/Steps-to-join-Pathfinder-Rocket.Chat
[least privilege principle]: https://csrc.nist.gov/glossary/term/least-privilege
