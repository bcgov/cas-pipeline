# CAS ElasticSearch, Fluent Bit, and Kibana

This chart deploys ElasticSearch and Kibana to a namespace, ready to be used alongside the CAS-logging-sidecar chart which comprises the Fluent Bit part of the EFK stack.

## TLS Internode Certificates

In order to enable inter-node security, and therefore basic auth, a certificate authority needs to be generated to be used by ElasticSearch. This is currently done manually, but only needs to be done if the certificate authority isn't already in the OpenShift Namespace's secret store. These directions can also be used to rotate/update an existing certificate authority.

### Directions

1. Get your login command from the OpenShift cluster and login in your terminal. _Ensure you are logged in to the correct project_!
1. In your `values.yaml` file, change `elasticsearch.security` to `false` and `elastic.replicas` to `1`.
1. Use `helm install` to temporarily deploy Elastic to the cluster.
1. In your console, use `oc get pods` in your namespace to find the deployed Elastic pod name. It should be named something like `es-cluster-0`. Use this wherever you see `<pod-name>` in the directions below.
1. Use `oc exec -it <pod-name> -- bash` to get a shell in the Elastic pod.
1. Run `bin/elasticsearch-certutil ca --pem --pass <PASSWORD> --silent --out ./certs/elastic-stack-ca.zip` to generate the certificate authority. *Ensure that you store the password in 1pass and as a secret in the namespace*.
1. Exit the shell.
1. Run `mkdir certs && oc cp es-cluster-0:/usr/share/elasticsearch/certs/elastic-stack-ca.zip ./certs/elastic-stack-ca.zip` to copy the certificate authority to a local directory.
1. Unzip the CA with `unzip ./certs/elastic-stack-ca.zip -d ./certs`.
1. Run `oc create secret generic <secret-name> --from-file=certs/ca/ca.crt --from-file=certs/ca/ca.key -n <namespace>` to create a secret with the certificate authority.
