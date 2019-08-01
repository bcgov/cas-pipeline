[![CircleCI](https://circleci.com/gh/bcgov/cas-pipeline/tree/master.svg?style=svg)](https://circleci.com/gh/bcgov/cas-pipeline/tree/master)

# cas-pipeline
A collection of make functions used to compose pipelines

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

The preferred name of the submodule folder is `.pipline`:

```
git submodule add https://github.com/bcgov/cas-pipeline.git .pipeline
```

For help, please visit [#cas] on [public team chat].

## related
- [openshift-developer-tools](https://github.com/BCDevOps/openshift-developer-tools/tree/master/bin)
- [bcdk](https://github.com/BCDevOps/bcdk/tree/release/0.0.1)
- [extended-oc](https://github.com/bcgov/esm-server/blob/dev/openshift/templates/lib/extended-oc.sh)
- [mds/pipeline](https://github.com/bcgov/mds/tree/develop/pipeline)

[Pathfinder]:https://developer.gov.bc.ca/What-is-Pathfinder
[OCP]:https://www.openshift.com/products/container-platform
[k8s namespaces]:https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/
[submodule]:https://git-scm.com/book/en/v2/Git-Tools-Submodules
[#cas]:https://chat.pathfinder.gov.bc.ca/channel/cas
[public team chat]:https://developer.gov.bc.ca/Steps-to-join-Pathfinder-Rocket.Chat
