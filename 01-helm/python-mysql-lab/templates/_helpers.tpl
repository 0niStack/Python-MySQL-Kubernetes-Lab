{{/* Resolve the StorageClass used by the MySQL PVC. Fails fast on bad input. */}}
{{- define "pml.storageClassName" -}}
{{- if eq .Values.storage.type "longhorn" -}}
{{- .Values.storage.longhorn.storageClassName -}}
{{- else if eq .Values.storage.type "local" -}}
{{- if eq .Values.storage.local.mode "static" -}}
{{- .Values.storage.local.static.storageClassName -}}
{{- else if eq .Values.storage.local.mode "dynamic" -}}
{{- .Values.storage.local.storageClassName -}}
{{- else -}}
{{- fail "storage.local.mode must be 'dynamic' or 'static'" -}}
{{- end -}}
{{- else -}}
{{- fail "storage.type must be 'local' or 'longhorn'" -}}
{{- end -}}
{{- end -}}

{{- define "pml.labels" -}}
app.kubernetes.io/part-of: python-mysql-lab
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end -}}
