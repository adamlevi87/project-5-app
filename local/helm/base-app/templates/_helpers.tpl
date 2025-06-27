{{- define "common.fullname" -}}
{{ .Release.Name }}
{{- end }}

{{- define "common.labels" -}}
app.kubernetes.io/name: {{ .Release.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app: {{ .Release.Name }}
{{- end }}