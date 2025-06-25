{{- define "{{ .Chart.Name }}.fullname" -}}
{{ .Release.Name }}
{{- end }}

{{- define "{{ .Chart.Name }}.labels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}