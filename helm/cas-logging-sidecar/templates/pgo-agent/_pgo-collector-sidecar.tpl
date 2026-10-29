{{/*
Place this in the `spec.instances.containers` section in the PGO chart.
Context needed for this templated, passed as a dict:
  appName: Name of the application.
  values: The `.Values` object from the Helm chart (`.` global context is not requied). If this template is used as a dependency, this should be `.Values.{depdency-chart-alias-or-name}` to pass the proper scope.
*/}}
{{- define "vector-pgo-collector.container" -}}
{{- $appName := .appName -}}
{{- $values := .values }}
- name: vector-collector
  image: {{ $values.collector.image.repository}}:{{ $values.collector.image.tag }}
  restartPolicy: Always
  args:
    - '--config'
    - '/etc/postgres/vector.yaml'
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
  - name: postgres-data
    readOnly: false
    mountPath: /pgdata
  - name: postgres-config
    readOnly: false
    mountPath: /etc/vector
{{- end -}}

{{- define "vector-pgo-collector.config-mount" -}}
- configMap:
  name: {{ .Release.Name }}-vector-pgo-collector-config
{{- end -}}
