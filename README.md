# Achat — DevSecOps Project

> **Module:** DevOps / DevSecOps — ESPRIT  
> **Stack:** Java 8 · Spring Boot 2.5.3 · Maven · MySQL · Docker · Jenkins · SonarQube · Nexus · Prometheus · Grafana

---

## What this project does

**Achat** is a REST backend for a procurement/purchasing system. It manages:

| Domain | Endpoints |
|--------|-----------|
| Suppliers (`/fournisseur`) | CRUD + assign activity sector |
| Products (`/produit`) | CRUD + assign to stock |
| Product Categories (`/categorieProduit`) | CRUD |
| Stock (`/stock`) | CRUD + retrieve unsecured stock |
| Invoices (`/facture`) | CRUD + cancel + recovery rate KPI |
| Payments (`/reglement`) | CRUD + revenue between dates KPI |
| Operators (`/operateur`) | CRUD |
| Activity Sectors (`/secteurActivite`) | CRUD |

API documentation is available at: `http://localhost:8089/SpringMVC/swagger-ui/`

---

## Prerequisites

| Tool | Version |
|------|---------|
| Java | 8+ |
| Maven | 3.6+ |
| MySQL | 8.0+ |

---

## Run locally

```bash
# 1. Create the database
mysql -u root -p -e "CREATE DATABASE achatdb;"

# 2. Configure credentials
# Edit src/main/resources/application.properties
# Set spring.datasource.username and spring.datasource.password

# 3. Build and run
mvn spring-boot:run
```

App starts at: `http://localhost:8089/SpringMVC`

---

## Branching strategy

```
main        ← stable, protected (requires PR + 1 approval)
develop     ← integration branch
feature/*   ← one branch per user story
hotfix/*    ← urgent production fixes
```

---

## CI/CD Pipeline (Week 2–6)

```
Git Push
  └─> Jenkins
        ├─ Checkout
        ├─ Build (Maven)
        ├─ Unit Tests (JUnit)
        ├─ SonarQube Analysis
        ├─ OWASP Dependency-Check
        ├─ Publish to Nexus
        ├─ Docker Build + Trivy Scan
        └─ Docker Run / Deploy
              └─> Prometheus scrapes /actuator/prometheus
                    └─> Grafana dashboard
```

---

## Team

| Role | Responsibility |
|------|---------------|
| Scrum Master | Sprint planning, backlog, ceremonies |
| Developer | Feature implementation, unit tests |
| QA | Test coverage, bug tracking |
| DevOps | CI/CD, Docker, monitoring, security |

---

## Week-by-week deliverables

| Week | Goal |
|------|------|
| 1 | Git setup, team roles, backlog, architecture doc |
| 2 | Jenkins CI pipeline (Checkout → Build → Test) |
| 3 | SonarQube + Nexus integration |
| 4 | Docker containerization |
| 5 | Prometheus + Grafana monitoring |
| 6 | DevSecOps hardening (OWASP, Trivy, secrets) |
| 7 | Final demo & presentation |
 
 
 
