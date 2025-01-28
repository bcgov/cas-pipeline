# CAS ElasticSearch, Fluent Bit, and Kibana

This chart deploys ElasticSearch and Kibana to a namespace, ready to be used alongside the CAS-logging-sidecar chart which comprises the Fluent Bit part of the EFK stack.

## TLS Internode Certificates

In order to enable inter-node security, and therefore basic auth, certificates and a certificate authority need to be generated to be used by ElasticSearch. This is currently done manually, but only needs to be done if the certificates aren't already in the OpenShift Namespace's secret store (ie. increasing the number of replicas). These directions can also be used to rotate/update existing certificates.

### Directions

1. Get your login command from the OpenShift cluster and login in your terminal. _Ensure you are logged in to the correct project_!
1. In your `values.yaml` file, change `elasticsearch.security` to `false` and `elastic.replicas` to `1`.
1. Use `helm install` to temporarily deploy Elastic to the cluster.
1. In your console, use `oc get pods` in your namespace to find the deployed Elastic pod name. It should be named something like `es-cluster-0`. Use this wherever you see `<pod-name>` in the directions below.
1. Use `oc exec -it <pod-name> -- bash` to get a shell in the Elastic pod.
1. Run `bin/elasticsearch-certutil ca --pem --silent --out ./certs/elastic-stack-ca.zip` to generate the certificate authority.
1. Run `unzip ./certs/elastic-stack-ca.zip -d ./certs` to unzip the certificate authority.
1. Run `bin/elasticsearch-certutil cert --pem --ca-cert ./certs/ca/ca.crt --ca-key ./certs/ca/ca.key --out ./certs/certificate-bundle.zip --multiple` to generate the node certificates. You will be prompted for an instance name, which should be `es-cluster-0` for the first instance. For the DNS names, enter a comma separated list. This list should have the instance name, and a then `*.<instance-name>.<namespace>.svc.cluster.local`. For example, if you are deploying the cluster to the `abc-123` namespace, you would enter `es-cluster-0,*.abc-123.svc.cluster.local`. You can leave the other fields blank. When given the option to specify another instance, enter `y` and repeat for each instance (ie. for 3 replica cluster, you will need `es-cluster-0`, `es-cluster-1`, and `es-cluster-2`).
1. Exit the shell.
1. Run `mkdir certs && oc cp es-cluster-0:/usr/share/elasticsearch/certs ./certs` to copy the certificates to a local directory.
1. Unzip the certificate bundle with `unzip ./certs/certificate-bundle.zip -d ./certs`.
1. Run `oc create secret generic <secret-name> --from-file=certs/ca/ca.crt --from-file=certs/ca/ca.key --from-file=certs/es-cluster-0.crt --from-file=certs/es-cluster-0.key --from-file=certs/es-cluster-1.crt --from-file=certs/es-cluster-1.key --from-file=certs/es-cluster-2.crt --from-file=certs/es-cluster-2.key -n <namespace>` to create a secret with the certificates. If there are more than 3 replicas, add the other `.key`/`.crt` certificates to the secret.
