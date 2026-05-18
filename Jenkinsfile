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
        DOCKER_IMAGE  = 'achat'
        APP_BASE_URL  = 'http://host.docker.internal:8089/SpringMVC'
    }

    // ── Pipeline options ────────────────────────────────────────
    options {
        buildDiscarder(logRotator(numToKeepStr: '5'))
        timeout(time: 60, unit: 'MINUTES')
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
                sh 'docker rm -f achat-app2 achat.2-mysql 2>/dev/null || true'
                // -v removes mysql-data so root password always matches .env (stale volume = Access denied / app crash)
                sh 'docker-compose down -v --remove-orphans || true'
                sh 'docker-compose up -d --no-build mysql app'
                echo 'Waiting for MySQL + Spring Boot to be ready...'
                sh """
                    for i in \$(seq 1 60); do
                      if docker run --rm --add-host=host.docker.internal:host-gateway curlimages/curl:8.5.0 -sf \\
                        ${APP_BASE_URL}/categorieProduit/retrieve-all-categorieProduit >/dev/null 2>&1; then
                        echo "App is up after attempt \${i}"
                        exit 0
                      fi
                      echo "Waiting for app... (\${i}/60)"
                      sleep 5
                    done
                    echo "App did not become ready — compose logs:"
                    docker-compose logs --tail=80 app mysql || true
                    exit 1
                """
                echo "Stack started — app available at ${APP_BASE_URL}"
            }
            post {
                success {
                    echo "Stack is up: achat-mysql + achat-app running via docker-compose."
                }
                failure {
                    echo 'Docker Run FAILED. Check docker-compose logs for details.'
                }
            }
        }

        // ══════════════════════════════════════════════════════
        // STAGE 10 — OWASP ZAP Baseline (DAST)
        // ══════════════════════════════════════════════════════
        // Dynamic scan against the running app (after Docker Run).
        // Report archived as zap-baseline-report.html per build.
        stage('OWASP ZAP Baseline') {
            steps {
                echo '========== OWASP ZAP baseline scan =========='
                // ZAP only requires /zap/wrk to exist (not a Docker volume). Copy reports out with docker cp (DinD-safe).
                sh """
                    mkdir -p target
                    docker pull ghcr.io/zaproxy/zaproxy:stable
                    docker rm -f zap-baseline-ci 2>/dev/null || true
                    docker run --name zap-baseline-ci \
                      --volumes-from jenkins \
                      --user root \
                      --add-host=host.docker.internal:host-gateway \
                      --entrypoint bash \
                      ghcr.io/zaproxy/zaproxy:stable \
                      -c "mkdir -p /zap/wrk && cd /zap/wrk && zap-baseline.py \\
                        -t ${APP_BASE_URL}/categorieProduit/retrieve-all-categorieProduit \\
                        -r zap-baseline-report.html \\
                        -J zap-baseline-report.json \\
                        --autooff \\
                        -I" 2>&1 | tee zap-baseline-console.log || true
                    docker cp zap-baseline-ci:/zap/wrk/zap-baseline-report.html . 2>/dev/null || true
                    docker cp zap-baseline-ci:/zap/wrk/zap-baseline-report.json . 2>/dev/null || true
                    docker rm -f zap-baseline-ci 2>/dev/null || true
                    cp -f zap-baseline-report.html target/zap-baseline-report.html 2>/dev/null || true
                    cp -f zap-baseline-report.json target/zap-baseline-report.json 2>/dev/null || true
                    ls -la zap-baseline-report.* target/zap-baseline-report.* zap-baseline-console.log 2>/dev/null || true
                    if ! test -s zap-baseline-report.html && ! test -s target/zap-baseline-report.html; then
                      echo "ERROR: ZAP did not produce zap-baseline-report.html in workspace"
                      echo "---- last 80 lines of zap-baseline-console.log ----"
                      tail -n 80 zap-baseline-console.log 2>/dev/null || true
                      exit 1
                    fi
                """
            }
            post {
                always {
                    archiveArtifacts artifacts: 'zap-baseline-report.html, zap-baseline-report.json, zap-baseline-console.log, target/zap-baseline-report.*',
                                     allowEmptyArchive: true,
                                     fingerprint: true
                    echo 'ZAP baseline reports archived (HTML/JSON/console).'
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
