---
name: kubernetes
description: Kubernetes manifests, deployments, services, GitOps
---

# Kubernetes — Manifests e GitOps

## Workflow GitOps (Regra Inviolável)

- Mudanças em workloads K8s vão via **commit** nos repos `argocd-manifests-*`
- **PROIBIDO** `kubectl apply`, `kubectl patch` direto em produção
- Valide localmente antes do PR: `kubectl diff -f manifests/`
- Use `argocd app diff` para verificar drift

## Estrutura de Manifests

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ nome-aplicacao }}
  namespace: {{ namespace }}
  labels:
    app.kubernetes.io/name: {{ nome }}
    app.kubernetes.io/component: {{ componente }}
    app.kubernetes.io/managed-by: argocd
spec:
  replicas: 2
  selector:
    matchLabels:
      app.kubernetes.io/name: {{ nome }}
  template:
    metadata:
      labels:
        app.kubernetes.io/name: {{ nome }}
      annotations:
        cluster-autoscaler.kubernetes.io/safe-to-evict: "true"
    spec:
      containers:
        - name: {{ nome }}
          image: {{ registry }}/{{ imagem }}:{{ sha-ou-versao-exata }}
          ports:
            - containerPort: 8080  # .NET 8+ usa 8080 por padrão (non-root)
          resources:
            requests:
              cpu: 100m       # Valores REALISTAS — afetam autoscaler
              memory: 128Mi
            limits:
              cpu: 500m
              memory: 512Mi
```

## Health Probes (Obrigatórias)

```yaml
startupProbe:          # Aguarda app inicializar (apps lentas)
  httpGet:
    path: /healthz
    port: 8080
  failureThreshold: 30
  periodSeconds: 2
livenessProbe:         # Reinicia container travado
  httpGet:
    path: /healthz
    port: 8080
  periodSeconds: 10
  failureThreshold: 3
readinessProbe:        # Remove do Service enquanto não pronto
  httpGet:
    path: /ready
    port: 8080
  periodSeconds: 5
  failureThreshold: 3
```

- `startupProbe` evita que `livenessProbe` mate apps que demoram a subir
- Endpoints de health separados de endpoints de readiness

## Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ nome }}
spec:
  selector:
    app.kubernetes.io/name: {{ nome }}
  ports:
    - port: 80
      targetPort: 8080   # ATENÇÃO: .NET 8+ escuta em 8080 (non-root)
      protocol: TCP
```

## HPA — Autoscaling Horizontal

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ nome }}
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
```

- Requests realistas são **obrigatórios** — HPA calcula % sobre requests
- `minReplicas: 2` para disponibilidade mínima

## PodDisruptionBudget

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
spec:
  minAvailable: 1    # Pelo menos 1 pod sempre disponível
  selector:
    matchLabels:
      app.kubernetes.io/name: {{ nome }}
```

## NetworkPolicy (Isolamento)

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: {{ nome }}-allow-ingress
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: {{ nome }}
  policyTypes: [Ingress]
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              name: ingress-nginx
      ports:
        - port: 8080
```

## Validação

```bash
# Lint dos manifests
kube-linter lint manifests/

# Diff contra o cluster (nunca apply direto)
kubectl diff -f manifests/
```

## Pegadinhas Conhecidas

- `.NET 8+` em imagens oficiais escuta na **porta 8080** (non-root) — `targetPort` deve refletir
- AKS autoscaler scale-down: requests **realistas** obrigatórios
- Anotação `safe-to-evict: "true"` necessária para pods com volumes efêmeros
- Image tags: SHA ou versão exata, **nunca** `:latest`
- Secrets: use External Secrets Operator ou Sealed Secrets, nunca plain text
