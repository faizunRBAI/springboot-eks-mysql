# springboot-eks-mysql

Production-ready Spring Boot 3 REST API deployed on Amazon EKS with RDS MySQL 8.4, built from the **Spring Boot API on Amazon EKS** blueprint.

---

## What it does

A JSON REST API for managing items, backed by a persistent MySQL database. Every deploy goes through **7 parallel security gates** before a single AWS resource is touched, then rolls out to Kubernetes with zero downtime.

**Endpoints**

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/health` | Simple liveness response (used by NLB health checks) |
| `GET` | `/api/info` | Application name and status |
| `GET` | `/api/items` | List all items |
| `POST` | `/api/items` | Create an item `{"name": "...", "description": "..."}` |
| `GET` | `/api/items/{id}` | Get one item |
| `DELETE` | `/api/items/{id}` | Delete one item |
| `GET` | `/actuator/health` | Spring Actuator health (liveness + readiness probes) |
| `GET` | `/actuator/health/liveness` | Kubernetes liveness probe |
| `GET` | `/actuator/health/readiness` | Kubernetes readiness probe |

---

## Architecture

```
API Clients → Network Load Balancer → Spring Boot Pods (EKS) → RDS MySQL
                                              ↑
                                       Image Registry (ECR)
```

See `.udap/architecture.d2` for the full diagram.

**Infrastructure**

| Component | Detail |
|-----------|--------|
| EKS | Kubernetes 1.33, KMS Secret encryption, audit logs |
| Node group | 2–4 × t3.medium (HPA on CPU 70%) |
| VPC | 2 public subnets (nodes/NLB) + 2 private subnets (RDS), 2 AZs |
| ECR | Scan-on-push, 20-image lifecycle policy |
| RDS MySQL | 8.4 LTS, db.t4g.micro, encrypted, 7-day backups |
| NLB | Network Load Balancer (Layer 4) |
| KMS | Envelope encryption for Kubernetes Secrets |

---

## Run locally

**Prerequisites:** Java 21, Maven 3.9+, Docker, a MySQL 8.x instance.

```bash
# Start a local MySQL via Docker
docker run -d \
  --name mysql-local \
  -e MYSQL_ROOT_PASSWORD=localdev \
  -e MYSQL_DATABASE=appdb \
  -e MYSQL_USER=app \
  -e MYSQL_PASSWORD=localdev \
  -p 3306:3306 \
  mysql:8.4

# Run the application
export SPRING_DATASOURCE_URL="jdbc:mysql://localhost:3306/appdb?useSSL=false&serverTimezone=UTC&characterEncoding=utf8mb4"
export SPRING_DATASOURCE_USERNAME=app
export SPRING_DATASOURCE_PASSWORD=localdev
./mvnw spring-boot:run

# Test it
curl http://localhost:8080/health
curl http://localhost:8080/api/items
curl -X POST http://localhost:8080/api/items \
  -H 'Content-Type: application/json' \
  -d '{"name":"hello","description":"world"}'
```

---

## Run tests

```bash
./mvnw test           # Unit tests (uses H2 in-memory, no real MySQL needed)
./mvnw checkstyle:check   # Lint
```

---

## How it deploys

The pipeline runs automatically on every push to `main`.

### Stage graph

```
lint ─┐
test ─┤
sast ─┤
secrets_scan ─┼─→ provision → build_push → image_scan → configure → verify → notify
license_scan ─┤                                 ↑
sbom ─────────┤                         (Trivy image scan)
iac_scan ─────┘
```

| Stage | What it does |
|-------|-------------|
| `lint` | Checkstyle coding-standards check |
| `test` | Maven unit tests |
| `sast` | Semgrep OWASP + Java rules |
| `secrets_scan` | Gitleaks secret detection |
| `sbom` | CycloneDX dependency bill of materials |
| `license_scan` | Licence compliance against an approved allowlist |
| `iac_scan` | Trivy + Checkov Terraform security scan |
| `provision` | Terraform: VPC, EKS, ECR, RDS MySQL |
| `build_push` | Docker build + push to ECR |
| `image_scan` | Trivy container image scan (HIGH/CRITICAL block) |
| `configure` | kubeconfig, Flyway migration Job, Kubernetes manifests |
| `verify` | NLB health check with retries |
| `notify` | GitHub Step Summary with the live URL |

---

## Configuration

All runtime configuration is injected via environment variables / Kubernetes Secrets.

| Variable | Where it's set | Description |
|----------|---------------|-------------|
| `SPRING_DATASOURCE_URL` | `app-database` K8s Secret | JDBC URL for RDS MySQL |
| `SPRING_DATASOURCE_USERNAME` | `app-database` K8s Secret | DB username |
| `SPRING_DATASOURCE_PASSWORD` | `app-database` K8s Secret | DB password |
| `DB_PASSWORD` | Pipeline secret | Set via `set_pipeline_secret` before deploy |

---

## Operations

**Check pod health**
```bash
aws eks update-kubeconfig --name <PROJECT_NAME>-eks --region us-east-1
kubectl get pods -n <PROJECT_NAME>
kubectl logs -n <PROJECT_NAME> -l app.kubernetes.io/name=api --tail=100
```

**Get the live URL**
```bash
kubectl get svc api -n <PROJECT_NAME>
```

**Run migrations manually**
```bash
kubectl delete job db-migrate -n <PROJECT_NAME> --ignore-not-found
# Edit k8s/db-migrate-job.yaml with the correct image tag, then:
kubectl apply -f k8s/db-migrate-job.yaml
kubectl logs job/db-migrate -n <PROJECT_NAME> -f
```

**Scale the deployment**
```bash
kubectl scale deployment api --replicas=3 -n <PROJECT_NAME>
# Or update node_desired_size/app_replicas in infra/variables.tf and push.
```

**Destroy the stack**
Trigger the Destroy workflow from GitHub Actions → workflow_dispatch. The pipeline removes the Kubernetes NLB first (to avoid `DependencyViolation`) then runs `terraform destroy`.

---

## Security artefacts

Each CI run uploads the following artefacts (retained 30–90 days):

- `semgrep-sast` — SARIF report of SAST findings
- `gitleaks-report` — SARIF report of secret scan
- `sbom-source` — CycloneDX SBOM of dependency graph
- `sbom-image` — CycloneDX SBOM of the container image
- `licence-report` — CSV of all dependency licences
- `test-reports` — Surefire unit test reports
