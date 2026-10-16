{{/* Shared pod template for the ingest Job and CronJob: the app image, the app's config and Secret, the app's security posture. */}}
{{- define "bank-agent.ingestPodSpec" -}}
restartPolicy: OnFailure
serviceAccountName: {{ include "bank-agent.serviceAccountName" . }}
automountServiceAccountToken: false
{{- with .Values.imagePullSecrets }}
imagePullSecrets:
  {{- toYaml . | nindent 2 }}
{{- end }}
securityContext:
  {{- toYaml .Values.podSecurityContext | nindent 2 }}
containers:
  - name: ingest
    image: {{ include "bank-agent.image" . }}
    imagePullPolicy: {{ .Values.image.pullPolicy }}
    command: ["python", "ingest.py"]
    envFrom:
      - configMapRef:
          name: {{ include "bank-agent.fullname" . }}-config
      - secretRef:
          name: {{ .Values.existingSecret }}
    env:
      - name: GIT_SHA
        value: {{ .Chart.AppVersion | quote }}
    securityContext:
      {{- toYaml .Values.securityContext | nindent 6 }}
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: "1"
        memory: 512Mi
    volumeMounts:
      - name: tmp
        mountPath: /tmp
volumes:
  - name: tmp
    emptyDir: {}
{{- end -}}
