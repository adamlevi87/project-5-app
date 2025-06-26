{{- define "common.fullname" -}}
{{ .Release.Name }}
{{- end }}

{{- define "common.labels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}