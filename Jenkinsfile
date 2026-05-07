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
    }

    // ── Pipeline options ────────────────────────────────────────
    options {
        buildDiscarder(logRotator(numToKeepStr: '5'))
        timeout(time: 20, unit: 'MINUTES')
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
        // STAGE 6 — OWASP Dependency-Check
        // ══════════════════════════════════════════════════════
        // Scans Maven dependencies for known CVEs (Week 6 — Security).
        // Generates an HTML report archived as a Jenkins artifact.
        stage('OWASP Dependency-Check') {
            steps {
                echo '========== Running OWASP Dependency-Check =========='
                // Use Jenkins-stored NVD API key (credentialsId: nvd-api-key).
                // If the credential is missing, the scan still runs but may
                // hit NVD rate limits (warnings only — pipeline keeps going).
                withCredentials([string(credentialsId: 'nvd-api-key',
                                         variable: 'NVD_API_KEY')]) {
                    sh '''
                        mvn org.owasp:dependency-check-maven:check \
                          -DskipTests \
                          -DnvdApiKey=$NVD_API_KEY || true
                    '''
                }
            }
            post {
                always {
                    archiveArtifacts artifacts: 'target/dependency-check-report.html',
                                     allowEmptyArchive: true,
                                     fingerprint: true
                    echo 'OWASP Dependency-Check report archived.'
                }
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
        // STAGE 8 — Trivy Image Scan
        // ══════════════════════════════════════════════════════
        // Scans the freshly built Docker image for OS-level CVEs
        // (Week 6 — Security). Uses the official aquasec/trivy image
        // so nothing extra needs to be installed on the agent.
        stage('Trivy Image Scan') {
            steps {
                echo '========== Scanning Docker image with Trivy =========='
                sh """
                    docker run --rm \
                      -v /var/run/docker.sock:/var/run/docker.sock \
                      -v \$(pwd):/report \
                      aquasec/trivy:latest image \
                      --severity HIGH,CRITICAL \
                      --no-progress \
                      --format table \
                      --output /report/trivy-report.txt \
                      ${DOCKER_IMAGE}:${JAR_VERSION} || true
                """
            }
            post {
                always {
                    archiveArtifacts artifacts: 'trivy-report.txt',
                                     allowEmptyArchive: true,
                                     fingerprint: true
                    echo 'Trivy scan report archived.'
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
                sh 'docker-compose down --remove-orphans || true'
                sh 'docker-compose up -d'
                echo 'Stack started — app available at http://localhost:8089'
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
