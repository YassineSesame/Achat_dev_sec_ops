# Architecture Overview — Achat

## 1. Application Type
REST JSON API — Spring Boot monolith, no frontend included.

## 2. Technology Stack

| Layer | Technology |
|-------|-----------|
| Language | Java 8 |
| Framework | Spring Boot 2.5.3 |
| Web | Spring MVC (REST controllers) |
| Persistence | Spring Data JPA + Hibernate 5 |
| Database | MySQL 8 (schema: `achatdb`) |
| Build | Maven 3 → executable JAR |
| API Docs | Springfox 3.0.0 (Swagger UI) |
| Utilities | Lombok |

## 3. Package Structure

```
tn.esprit.rh.achat
├── AchatApplication.java          ← @SpringBootApplication entry point
├── controllers/                   ← REST layer (@RestController)
│   ├── ProduitRestController
│   ├── CategorieProduitController
│   ├── StockRestController
│   ├── FactureRestController
│   ├── FournisseurRestController
│   ├── ReglementRestController
│   ├── SecteurActiviteController
│   └── OperateurController
├── services/                      ← Business logic (interface + impl)
│   ├── I*Service (interfaces)
│   └── *ServiceImpl (implementations)
├── repositories/                  ← Spring Data JPA repositories
├── entities/                      ← JPA entities (@Entity)
│   ├── Produit
│   ├── CategorieProduit
│   ├── Stock
│   ├── Facture
│   ├── DetailFacture
│   ├── Fournisseur
│   ├── DetailFournisseur
│   ├── CategorieFournisseur (enum)
│   ├── SecteurActivite
│   ├── Reglement
│   └── Operateur
└── util/
    └── SpringFoxSwaggerConfig     ← Swagger configuration
```

## 4. Domain Model (Entity Relationships)

```
Fournisseur  ──< Facture  ──< DetailFacture >── Produit >── Stock
                   │                                │
                   └──< Reglement          CategorieProduit
                   │
                Operateur
                
Fournisseur >──< SecteurActivite
CategorieFournisseur (enum on Fournisseur)
```

## 5. API Configuration
- **Base URL:** `http://localhost:8089/SpringMVC`
- **Swagger UI:** `http://localhost:8089/SpringMVC/swagger-ui/`
- **CORS:** open (`*`) on all controllers (dev only — must be restricted in prod)
- **Security:** none currently (no Spring Security configured)

## 6. Database Configuration
- Host: `localhost:3306`
- Schema: `achatdb`
- DDL mode: `update` (Hibernate auto-creates/updates tables)
- Credentials stored in `application.properties` ⚠️ (to be moved to env vars in Week 6)

## 7. Identified Weaknesses

| # | Weakness | Risk | Week to address |
|---|----------|------|----------------|
| 1 | No unit/integration tests | Pipeline Test stage will fail / be empty | Week 2 |
| 2 | DB credentials in `application.properties` | Secret exposure | Week 6 |
| 3 | No Spring Security | All endpoints publicly accessible | Week 6 |
| 4 | CORS open (`*`) | Any origin can call the API | Week 6 |
| 5 | No CI/CD | Manual build and deploy only | Week 2 |
| 6 | No containerization | Environment-dependent deployment | Week 4 |
| 7 | No metrics endpoint | No observability | Week 5 |
| 8 | Outdated dependencies (Spring Boot 2.5.3, mysql-connector 8.0.26) | Known CVEs | Week 6 |
| 9 | No artifact versioning | No traceability of released versions | Week 3 |
