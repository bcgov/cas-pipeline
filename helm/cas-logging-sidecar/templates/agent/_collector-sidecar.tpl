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
  values: The `.Values` object from the Helm chart. (`.` global context is not avaiable)
*/}}
{{- define "vector-collector.container" -}}
- name: logrotate
  image: {{ .Values.logRotate.image }}:{{ .Values.logRotate.imageTag }}
  restartPolicy: Always
  resources:
    {{- toYaml .Values.logRotate.resources | nindent 4 }}
  command:
    - "/bin/sh"
    - "-c"
    - "while true; do logrotate -s /var/log/logrotate.status -f /etc/sidecar/logrotate.conf; sleep 300; done"
  volumeMounts:
    {{- include "vector-collector.sidecarVolumeMounts" . | nindent 4 }}
- name: vector-collector
  image: timberio/vector:{{ .Values.collector.imageTag }}
  restartPolicy: Always
  command: ["/bin/sh", "-c"]
  args:
    - exec vector --config /etc/sidecar/vector.yaml
  env:
    - name: APP_NAME
      value: {{ .appName }}
  resources:
    {{- toYaml .Values.collector.resources | nindent 4 }}
  volumeMounts:
    {{- include "vector-collector.sidecarVolumeMounts" . | nindent 4 }}
    - name: data
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
- name: data
  emptyDir: {}
{{- end -}}
