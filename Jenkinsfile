pipeline {
    agent any

    // ── Tool configuration ──────────────────────────────────────
    // Make sure "Maven-3" matches the name you set in:
    // Jenkins → Manage Jenkins → Global Tool Configuration → Maven
    tools {
        maven 'Maven-3'
        jdk 'JDK-21'
    }

    // ── Environment variables ───────────────────────────────────
    environment {
        APP_NAME      = 'achat'
        JAR_VERSION   = '1.0'
        JAVA_HOME     = '/usr/lib/jvm/java-21-openjdk-amd64'
        PATH          = "/usr/lib/jvm/java-21-openjdk-amd64/bin:${env.PATH}"
        SONAR_URL     = 'http://host.docker.internal:9000'
        NEXUS_URL     = 'http://host.docker.internal:8081'
        JENKINS_URL   = 'http://host.docker.internal:8080'
        GRAFANA_URL   = 'http://host.docker.internal:3000'
        PROMETHEUS_URL = 'http://host.docker.internal:9090'
        CADVISOR_URL  = 'http://host.docker.internal:8085'
        DOCKER_IMAGE  = 'achat'
        APP_BASE_URL  = 'http://host.docker.internal:8089/SpringMVC'
    }

    // ── Pipeline options ────────────────────────────────────────
    options {
        buildDiscarder(logRotator(numToKeepStr: '5'))
        timeout(time: 90, unit: 'MINUTES')
        timestamps()
    }

    stages {

        // ══════════════════════════════════════════════════════
        // STAGE 1 — Checkout
        // ══════════════════════════════════════════════════════
        stage('Checkout') {
            steps {
                echo '========== Checking out source code =========='
                checkout scm
                echo "Branch: ${env.GIT_BRANCH}"
                echo "Commit: ${env.GIT_COMMIT}"
            }
        }

        // ══════════════════════════════════════════════════════
        // STAGE 2 — Build
        // ══════════════════════════════════════════════════════
        stage('Build') {
            steps {
                echo '========== Building with Maven =========='
                sh 'mvn clean package -DskipTests'
                echo "JAR produced: target/${APP_NAME}-${JAR_VERSION}.jar"
            }
            post {
                success {
                    archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
                    echo 'Build artifact archived.'
                }
                failure {
                    echo 'Build stage FAILED. Check Maven output above.'
                }
            }
        }

        // ══════════════════════════════════════════════════════
        // STAGE 3 — Test
        // ══════════════════════════════════════════════════════
        stage('Test') {
            steps {
                echo '========== Running JUnit tests =========='
                sh 'mvn test'
            }
            post {
                always {
                    junit testResults: 'target/surefire-reports/*.xml',
                          allowEmptyResults: true
                    echo 'JUnit results published.'
                }
                success {
                    echo 'All tests passed.'
                }
                failure {
                    echo 'Some tests FAILED. Check the test report above.'
                }
            }
        }

        // ══════════════════════════════════════════════════════
        // STAGE 4 — SonarQube Analysis
        // ══════════════════════════════════════════════════════
        // Requires in Jenkins:
        //   - SonarQube Scanner plugin installed
        //   - "SonarQube" server configured under Manage Jenkins → System
        //   - Token credential linked to that server
        stage('Sonar Analysis') {
            steps {
                echo '========== Running SonarQube Analysis =========='
                withSonarQubeEnv('SonarQube') {
                    sh '''
                        mvn sonar:sonar \
                          -Dsonar.projectKey=achat \
                          -Dsonar.projectName=achat \
                          -Dsonar.host.url=${SONAR_URL}
                    '''
                }
            }
            post {
                success {
                    echo "SonarQube report available at: ${SONAR_URL}/dashboard?id=achat"
                }
                failure {
                    echo 'Sonar analysis FAILED.'
                }
            }
        }

        // ══════════════════════════════════════════════════════
        // STAGE 5 — Publish to Nexus
        // ══════════════════════════════════════════════════════
        // Requires:
        //   - Nexus running on localhost:8081
        //   - maven-releases / maven-snapshots repositories created
        //   - ~/.m2/settings.xml on the Jenkins agent with
        //     server credentials for ids: nexus-releases / nexus-snapshots
        stage('Publish to Nexus') {
            steps {
                echo '========== Publishing JAR to Nexus =========='
                sh 'mvn deploy -DskipTests'
            }
            post {
                success {
                    echo "Artifact ${APP_NAME}-${JAR_VERSION}.jar published to Nexus."
                    echo "Browse it at: ${NEXUS_URL}/#browse/browse:maven-releases"
                }
                failure {
                    echo 'Deploy to Nexus FAILED. Check ~/.m2/settings.xml credentials.'
                }
            }
        }

        // ══════════════════════════════════════════════════════
        // STAGE 6 — OWASP Dependency-Check (DISABLED in CI)
        // ══════════════════════════════════════════════════════
        // The OWASP plugin is integrated in pom.xml and can be run
        // locally with:
        //   mvn org.owasp:dependency-check-maven:check -DnvdApiKey=...
        // It is intentionally NOT executed in CI to avoid blocking the
        // pipeline on NVD rate limits. Trivy (next stage) covers both
        // OS-level and Java dependency vulnerabilities.
        //
        // To re-enable, change the `when` clause below to `expression { true }`.
        stage('OWASP Dependency-Check') {
            when { expression { false } }
            steps {
                echo '========== OWASP scan skipped (run locally) =========='
            }
        }

        // ══════════════════════════════════════════════════════
        // STAGE 7 — Docker Build
        // ══════════════════════════════════════════════════════
        // Requires: Docker CLI installed on Jenkins agent and
        // Docker socket mounted (-v /var/run/docker.sock:/var/run/docker.sock)
        stage('Docker Build') {
            steps {
                echo '========== Building Docker image =========='
                sh "docker build -t ${DOCKER_IMAGE}:${JAR_VERSION} ."
                sh "docker tag ${DOCKER_IMAGE}:${JAR_VERSION} ${DOCKER_IMAGE}:latest"
                echo "Image built: ${DOCKER_IMAGE}:${JAR_VERSION}"
            }
            post {
                success {
                    echo "Docker image ${DOCKER_IMAGE}:${JAR_VERSION} created successfully."
                }
                failure {
                    echo 'Docker Build FAILED. Is the Docker socket mounted in Jenkins?'
                }
            }
        }

        // ══════════════════════════════════════════════════════
        // STAGE 8 — Trivy Security Scan (filesystem + image)
        // ══════════════════════════════════════════════════════
        // Trivy detects vulnerabilities in:
        //   - Java dependencies (pom.xml + JARs)
        //   - Docker image OS packages
        //   - Misconfigurations and exposed secrets
        // Replaces OWASP Dependency-Check (which is rate-limited by NVD).
        stage('Trivy Security Scan') {
            steps {
                echo '========== Trivy: scanning project filesystem =========='
                // Use --volumes-from to share Jenkins's workspace volume
                // with the Trivy container (Docker-in-Docker workaround).
                // The trivy-cache named volume persists DBs across builds
                // so they don't need to be re-downloaded each time.
                sh """
                    docker run --rm \
                      --volumes-from jenkins \
                      -v trivy-cache:/root/.cache/trivy \
                      -w \$(pwd) \
                      aquasec/trivy:latest fs \
                      --severity HIGH,CRITICAL \
                      --no-progress \
                      --timeout 30m \
                      --scanners vuln \
                      --format table \
                      . > trivy-fs-report.txt 2>&1 || true
                """

                echo '========== Trivy: scanning Docker image =========='
                sh """
                    docker run --rm \
                      -v /var/run/docker.sock:/var/run/docker.sock \
                      -v trivy-cache:/root/.cache/trivy \
                      aquasec/trivy:latest image \
                      --severity HIGH,CRITICAL \
                      --no-progress \
                      --timeout 30m \
                      --scanners vuln \
                      --format table \
                      ${DOCKER_IMAGE}:${JAR_VERSION} > trivy-image-report.txt 2>&1 || true
                """

                sh 'ls -la trivy-*.txt || true'
            }
            post {
                always {
                    archiveArtifacts artifacts: 'trivy-*-report.txt',
                                     allowEmptyArchive: true,
                                     fingerprint: true
                    echo 'Trivy reports archived (filesystem + image).'
                }
            }
        }

        // ══════════════════════════════════════════════════════
        // STAGE 9 — Docker Run (via docker-compose)
        // ══════════════════════════════════════════════════════
        // Brings up MySQL + the app together using docker-compose.
        // MySQL starts first (healthcheck), then the app connects.
        stage('Docker Run') {
            steps {
                echo '========== Starting stack with docker-compose =========='
                // .env is gitignored — create CI env file so compose can start MySQL + app
                sh '''
                    cat > .env << 'EOF'
MYSQL_ROOT_PASSWORD=root
MYSQL_DATABASE=achatdb
SPRING_DATASOURCE_USERNAME=root
SPRING_DATASOURCE_PASSWORD=root
GF_SECURITY_ADMIN_USER=admin
GF_SECURITY_ADMIN_PASSWORD=admin
EOF
                '''
                sh 'docker rm -f achat-app2 achat.2-mysql prometheus grafana cadvisor cadvisor1 2>/dev/null || true'
                sh 'if [ -d prometheus.yml ]; then rm -rf prometheus.yml && git checkout -- prometheus.yml 2>/dev/null || true; fi'
                // -v removes mysql-data so root password always matches .env (stale volume = Access denied / app crash)
                // docker-compose.ci.yml avoids host bind mounts (prometheus.yml) that fail in Jenkins DinD/Windows
                sh 'docker-compose -f docker-compose.ci.yml down -v --remove-orphans || true'
                sh 'docker-compose -f docker-compose.ci.yml up -d --no-build mysql app prometheus grafana cadvisor'
                echo 'Waiting for MySQL + Spring Boot to be ready...'
                sh """
                    for i in \$(seq 1 60); do
                      if docker run --rm --add-host=host.docker.internal:host-gateway curlimages/curl:8.5.0 -sf \\
                        ${APP_BASE_URL}/v2/api-docs >/dev/null 2>&1; then
                        echo "App is up after attempt \${i}"
                        exit 0
                      fi
                      echo "Waiting for app... (\${i}/60)"
                      sleep 5
                    done
                    echo "App did not become ready — compose logs:"
                    docker-compose -f docker-compose.ci.yml logs --tail=80 app mysql prometheus grafana || true
                    exit 1
                """
                echo "Stack started — app available at ${APP_BASE_URL}"
            }
            post {
                success {
                    echo "Stack is up: mysql + app + prometheus + grafana + cadvisor (CI compose)."
                }
                failure {
                    echo 'Docker Run FAILED. Check docker-compose logs for details.'
                }
            }
        }

        // ══════════════════════════════════════════════════════
        // STAGE 10 — OWASP ZAP (all HTTP services in the stack)
        // ══════════════════════════════════════════════════════
        // ZAP scans HTTP/HTTPS only. MySQL :3306 is skipped (use Trivy for images).
        // Targets: achat (OpenAPI + baseline), Jenkins, SonarQube, Nexus,
        //          Grafana, Prometheus, cAdvisor.
        stage('OWASP ZAP Scan') {
            steps {
                echo '========== OWASP ZAP: scanning all HTTP containers =========='
                sh """
                    mkdir -p target zap-reports
                    : > zap-reports/zap-scan-summary.txt
                    docker pull ghcr.io/zaproxy/zaproxy:stable

                    run_zap_baseline() {
                      local svc="\$1" url="\$2" mins="\${3:-2}"
                      echo "========== ZAP baseline: \${svc} => \${url} =========="
                      docker rm -f "zap-\${svc}" 2>/dev/null || true
                      docker run --name "zap-\${svc}" \\
                        --volumes-from jenkins \\
                        --user root \\
                        --add-host=host.docker.internal:host-gateway \\
                        --entrypoint bash \\
                        ghcr.io/zaproxy/zaproxy:stable \\
                        -c "mkdir -p /zap/wrk && cd /zap/wrk && zap-baseline.py \\
                          -t \${url} \\
                          -m \${mins} \\
                          -r zap-\${svc}-report.html \\
                          -J zap-\${svc}-report.json \\
                          --autooff \\
                          -I" 2>&1 | tee "zap-reports/\${svc}-console.log" || true
                      docker cp "zap-\${svc}:/zap/wrk/zap-\${svc}-report.html" zap-reports/ 2>/dev/null || true
                      docker cp "zap-\${svc}:/zap/wrk/zap-\${svc}-report.json" zap-reports/ 2>/dev/null || true
                      docker rm -f "zap-\${svc}" 2>/dev/null || true
                      if test -s "zap-reports/zap-\${svc}-report.html"; then
                        echo "OK   \${svc} \${url}" >> zap-reports/zap-scan-summary.txt
                      else
                        echo "FAIL \${svc} \${url} (service down or scan error)" >> zap-reports/zap-scan-summary.txt
                      fi
                    }

                    echo '--- achat: OpenAPI active scan (all REST endpoints) ---'
                    docker rm -f zap-achat-api 2>/dev/null || true
                    docker run --name zap-achat-api \\
                      --volumes-from jenkins \\
                      --user root \\
                      --add-host=host.docker.internal:host-gateway \\
                      --entrypoint bash \\
                      ghcr.io/zaproxy/zaproxy:stable \\
                      -c "mkdir -p /zap/wrk && cd /zap/wrk && zap-api-scan.py \\
                        -t ${APP_BASE_URL}/v2/api-docs \\
                        -f openapi \\
                        -O host.docker.internal \\
                        -r zap-achat-api-report.html \\
                        -J zap-achat-api-report.json \\
                        -T 20 \\
                        -I" 2>&1 | tee zap-reports/achat-api-console.log || true
                    docker cp zap-achat-api:/zap/wrk/zap-achat-api-report.html zap-reports/ 2>/dev/null || true
                    docker cp zap-achat-api:/zap/wrk/zap-achat-api-report.json zap-reports/ 2>/dev/null || true
                    docker rm -f zap-achat-api 2>/dev/null || true
                    if test -s zap-reports/zap-achat-api-report.html; then
                      echo "OK   achat-api ${APP_BASE_URL}/v2/api-docs" >> zap-reports/zap-scan-summary.txt
                    else
                      echo "FAIL achat-api ${APP_BASE_URL}/v2/api-docs" >> zap-reports/zap-scan-summary.txt
                    fi

                    echo '--- baseline DAST on each HTTP container ---'
                    echo "SKIP mysql:3306 (not HTTP — covered by Trivy image scan)" >> zap-reports/zap-scan-summary.txt
                    run_zap_baseline achat-app '${APP_BASE_URL}/' 3
                    run_zap_baseline jenkins '${JENKINS_URL}/' 2
                    run_zap_baseline sonarqube '${SONAR_URL}/' 2
                    run_zap_baseline nexus '${NEXUS_URL}/' 2
                    run_zap_baseline grafana '${GRAFANA_URL}/' 2
                    run_zap_baseline prometheus '${PROMETHEUS_URL}/' 2
                    run_zap_baseline cadvisor '${CADVISOR_URL}/' 2

                    cp -f zap-reports/* target/ 2>/dev/null || true
                    echo '========== ZAP scan summary =========='
                    cat zap-reports/zap-scan-summary.txt
                    ls -la zap-reports/ target/zap-*-report.* 2>/dev/null || true

                    if ! test -s zap-reports/zap-achat-api-report.html; then
                      echo "ERROR: achat OpenAPI scan did not produce a report (Swagger /v2/api-docs)"
                      tail -n 80 zap-reports/achat-api-console.log 2>/dev/null || true
                      exit 1
                    fi
                """
            }
            post {
                always {
                    archiveArtifacts artifacts: 'zap-reports/**, target/zap-*-report.*, target/zap-scan-summary.txt',
                                     allowEmptyArchive: true,
                                     fingerprint: true
                    echo 'ZAP reports archived (all HTTP containers + summary).'
                }
            }
        }

    }

    // ── Global post actions ─────────────────────────────────────
    post {
        success {
            echo """
            ╔══════════════════════════════════════╗
            ║   Pipeline PASSED ✔                  ║
            ║   App   : ${APP_NAME} v${JAR_VERSION} ║
            ║   Branch: ${env.GIT_BRANCH}          ║
            ╚══════════════════════════════════════╝
            """
        }
        failure {
            echo """
            ╔══════════════════════════════════════╗
            ║   Pipeline FAILED ✘                  ║
            ║   App   : ${APP_NAME}                ║
            ║   Branch: ${env.GIT_BRANCH}          ║
            ╚══════════════════════════════════════╝
            """
        }
        always {
            cleanWs()
        }
    }
}
