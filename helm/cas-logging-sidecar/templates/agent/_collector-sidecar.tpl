{{/*
Appends logging output tee to file and stdout from the main application.
*/}}
{{- define "vector-collector.tee" -}}
| tee -a /var/log/app/app.log
{{- end -}}

{{/*
Lists the volumeMounts required for the collector (common to both Vector and logrotate containers).
Adds configMaps from collector-configmap.yaml.
*/}}
{{- define "vector-collector.sidecarVolumeMounts" -}}
- name: vector-collector-logging-config
  mountPath: /etc/sidecar
  readOnly: true
- name: shared-logs
  mountPath: /var/log/app
  readOnly: true
{{- end -}}

{{/*
Place this in an `initContainers` section alongside the main application container. With `restartPolicy: Always` set,
the containers operate as sidecars. See the OpenShift documention or [Kubernetes documentation](https://kubernetes.io/docs/concepts/workloads/pods/sidecar-containers/) for details.
Creates the Vector container to collect logs as an collector from the main deployment container.
Creates the logrotate container to rotate logs.
Context needed for this templated, passed as a dict:
  appName: Name of the application.
  values: The `.Values` object from the Helm chart (`.` global context is not requied). If this template is used as a dependency, this should be `.Values.{depdency-chart-alias-or-name}` to pass the proper scope.
*/}}
{{- define "vector-collector.container" -}}
{{- $appName := .appName -}}
{{- $values := .values }}
- name: logrotate
  image: {{ $values.logRotate.image }}:{{ $values.logRotate.imageTag }}
  restartPolicy: Always
  resources:
    {{- toYaml $values.logRotate.resources | nindent 4 }}
  command:
    - "/bin/sh"
    - "-c"
    - "while true; do logrotate -s /var/log/logrotate.status -f /etc/sidecar/logrotate.conf; sleep 300; done"
  volumeMounts:
    {{- include "vector-collector.sidecarVolumeMounts" . | nindent 4 }}
- name: vector-collector
  image: {{ $values.collector.image.repository}}:{{ $values.collector.image.tag }}
  restartPolicy: Always
  args:
    - '--config'
    - '/etc/sidecar/vector.yaml'
  env:
    - name: APP_NAME
      value: {{ $appName | quote }}
    - name: VECTOR_SELF_NODE_NAME
      valueFrom:
        fieldRef:
          apiVersion: v1
          fieldPath: spec.nodeName
    - name: VECTOR_SELF_POD_NAME
      valueFrom:
        fieldRef:
          apiVersion: v1
          fieldPath: metadata.name
    - name: VECTOR_SELF_POD_NAMESPACE
      valueFrom:
        fieldRef:
          apiVersion: v1
          fieldPath: metadata.namespace
  resources:
    {{- toYaml $values.collector.resources | nindent 4 }}
  volumeMounts:
    {{- include "vector-collector.sidecarVolumeMounts" . | nindent 4 }}
    - name: vector-tmp-data
      mountPath: /tmp/vector
      readOnly: false
{{- end -}}

{{/*
Creates the volume mounts for the application log file.
*/}}
{{- define "vector-collector.applicationVolumeMounts" -}}
- name: shared-logs
  mountPath: /var/log/app
{{- end -}}

{{/*
Creates the volumes required for the log file and Vector collector.
*/}}
{{- define "vector-collector.loggingVolumes" -}}
- name: shared-logs
  emptyDir: {}
- name: vector-collector-logging-config
  configMap:
    name: {{ .Release.Name }}-vector-collector-config
- name: vector-tmp-data
  emptyDir: {}
{{- end -}}
