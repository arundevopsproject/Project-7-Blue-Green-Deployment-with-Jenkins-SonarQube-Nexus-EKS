pipeline {
    agent any
    
    tools {
        maven 'maven3'
    }
    
    parameters {
        choice(name: 'DEPLOY_ENV', choices: ['blue', 'green'], description: 'Choose which environment to deploy: Blue or Green')
        choice(name: 'DOCKER_TAG', choices: ['blue', 'green'], description: 'Choose the Docker image tag for the deployment')
        booleanParam(name: 'SWITCH_TRAFFIC', defaultValue: false, description: 'Switch traffic between Blue and Green')
    }
    
    environment {
        IMAGE_NAME = "ngozin/bankapp"
        TAG = "${params.DOCKER_TAG}"
        KUBE_NAMESPACE = 'webapps'
        SCANNER_HOME= tool 'sonar-scanner'
    }

    stages {
        stage('Git Checkout') {
            steps {
                git branch: 'main', credentialsId: 'git-cred', url: 'https://github.com/Ngozi-N/blue-green-deployment-project.git'
            }
        }
        
        stage('Compile') {
            steps {
                sh "mvn compile"
            }
        }
        
        stage('Tests') {
            steps {
                sh "mvn test -DskipTests=true"
            }
        }
        
        stage('Trivy FS Scan') {
            steps {
                sh "trivy fs --format table -o fs.html ."
            }
        }
        
        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('sonar') {
                    sh "$SCANNER_HOME/bin/sonar-scanner -Dsonar.projectKey=multitier -Dsonar.projectName=multitier -Dsonar.java.binaries=target"
                }
            }
        }
        
        stage('Quality Gate Check') {
            steps {
                timeout(time: 1, unit: 'HOURS') {
                    waitForQualityGate abortPipeline: false, credentialsId: 'sonar-token'
                }
            }
        }
        
        stage('Build') {
            steps {
                sh "mvn package -DskipTests=true"
            }
        }
        
        stage('Publish Artifact To Nexus') {
            steps {
                withMaven(globalMavenSettingsConfig: 'maven-settings', maven: 'maven3', traceability: true) {
                    sh "mvn deploy -DskipTests=true"
                }
            }
        }
        
        stage('Docker Build & Tag Image') {
            steps {
                script {
                    withDockerRegistry(credentialsId: 'docker-cred') {
                        sh "docker build -t ${IMAGE_NAME}:${TAG} ."
                    }
                }
            }
        }
        
        stage('Trivy Image Scan') {
            steps {
                sh '''
                  trivy image --format table -o trivy-image-${BUILD_NUMBER}.html ${IMAGE_NAME}:${TAG}
                '''
            }
        }
        
        stage('Docker Push Image') {
            steps {
                script {
                    withDockerRegistry(credentialsId: 'docker-cred') {
                        sh "docker push ${IMAGE_NAME}:${TAG}"
                    }
                }
            }
        }
        
        stage('Deploy MySQL Deployment and Service') {
          steps {
            script {
              withCredentials([file(credentialsId: 'eks-ca-pem-file', variable: 'CA_FILE')]) {
                def pem = readFile(file: env.CA_FILE)
                withKubeConfig(
                  serverUrl: 'https://F25367689CC0846FBC37DE698EB3D82A.gr7.eu-west-2.eks.amazonaws.com',
                  credentialsId: 'k8-token',
                  namespace: "${KUBE_NAMESPACE}",
                  restrictKubeConfigAccess: false,
                  caCertificate: pem
                ) {
                  // pick the right deployment manifest for the chosen environment
                  def DEPLOY_FILE = (params.DEPLOY_ENV == 'blue') ? 'app-deployment-blue.yml' : 'app-deployment-green.yml'
                  def DEPLOY_NAME = "bankapp-${params.DEPLOY_ENV}"
                  def CONTAINER   = "bankapp"    // <-- ensure this matches the container name in your Deployment spec
        
                  sh """
                    set -e
        
                    echo '== Apply MySQL (idempotent) =='
                    kubectl apply -f mysql-ds.yml -n ${KUBE_NAMESPACE}
        
                    echo '== Ensure ${DEPLOY_NAME} exists =='
                    if ! kubectl -n ${KUBE_NAMESPACE} get deploy ${DEPLOY_NAME} >/dev/null 2>&1; then
                      kubectl -n ${KUBE_NAMESPACE} apply -f ${DEPLOY_FILE}
                    fi
        
                    echo '== Point ${DEPLOY_NAME} at ${IMAGE_NAME}:${TAG} =='
                    kubectl -n ${KUBE_NAMESPACE} set image deploy/${DEPLOY_NAME} \
                      ${CONTAINER}=${IMAGE_NAME}:${TAG}
        
                    echo '== Wait for rollout =='
                    kubectl -n ${KUBE_NAMESPACE} rollout status deploy/${DEPLOY_NAME} --timeout=180s || true
        
                    echo '== Show endpoints (may be empty until a pod is Ready) =='
                    kubectl -n ${KUBE_NAMESPACE} get endpoints bankapp-service || true
                  """
                }
              }
            }
          }
        }
        
        stage('Deploy SVC-APP') {
          steps {
            script {
              withCredentials([file(credentialsId: 'eks-ca-pem-file', variable: 'CA_FILE')]) {
                def pem = readFile(file: env.CA_FILE)
                withKubeConfig(
                  serverUrl: 'https://F25367689CC0846FBC37DE698EB3D82A.gr7.eu-west-2.eks.amazonaws.com',
                  credentialsId: 'k8-token',
                  namespace: "${KUBE_NAMESPACE}",
                  restrictKubeConfigAccess: false,
                  caCertificate: pem
                ) {
                  sh """
                    if ! kubectl get svc bankapp-service -n ${KUBE_NAMESPACE}; then
                      kubectl apply -f bankapp-service.yml -n ${KUBE_NAMESPACE}
                    fi
                  """
                }
              }
            }
          }
        }
        
        stage('Deploy to Kubernetes') {
          steps {
            script {
              def deploymentFile = (params.DEPLOY_ENV == 'blue') ? 'app-deployment-blue.yml' : 'app-deployment-green.yml'
              withCredentials([file(credentialsId: 'eks-ca-pem-file', variable: 'CA_FILE')]) {
                def pem = readFile(file: env.CA_FILE)
                withKubeConfig(
                  serverUrl: 'https://F25367689CC0846FBC37DE698EB3D82A.gr7.eu-west-2.eks.amazonaws.com',
                  credentialsId: 'k8-token',
                  namespace: "${KUBE_NAMESPACE}",
                  restrictKubeConfigAccess: false,
                  caCertificate: pem
                ) {
                  sh "kubectl apply -f ${deploymentFile} -n ${KUBE_NAMESPACE}"
                }
              }
            }
          }
        }
        
        stage('Switch Traffic Between Blue & Green Environment') {
          when { expression { return params.SWITCH_TRAFFIC } }
          steps {
            script {
              def newEnv = params.DEPLOY_ENV
              withCredentials([file(credentialsId: 'eks-ca-pem-file', variable: 'CA_FILE')]) {
                def pem = readFile(file: env.CA_FILE)
                withKubeConfig(
                  serverUrl: 'https://F25367689CC0846FBC37DE698EB3D82A.gr7.eu-west-2.eks.amazonaws.com',
                  credentialsId: 'k8-token',
                  namespace: "${KUBE_NAMESPACE}",
                  restrictKubeConfigAccess: false,
                  caCertificate: pem
                ) {
                  sh """
                    kubectl patch service bankapp-service -n ${KUBE_NAMESPACE} \
                      -p '{\"spec\":{\"selector\":{\"app\":\"bankapp\",\"version\":\"${newEnv}\"}}}'
                  """
                  echo "Traffic has been switched to the ${newEnv} environment."
                }
              }
            }
          }
        }
        
        stage('Verify Deployment') {
          steps {
            script {
              def verifyEnv = params.DEPLOY_ENV
              withCredentials([file(credentialsId: 'eks-ca-pem-file', variable: 'CA_FILE')]) {
                def pem = readFile(file: env.CA_FILE)
                withKubeConfig(
                  serverUrl: 'https://F25367689CC0846FBC37DE698EB3D82A.gr7.eu-west-2.eks.amazonaws.com',
                  credentialsId: 'k8-token',
                  namespace: "${KUBE_NAMESPACE}",
                  restrictKubeConfigAccess: false,
                  caCertificate: pem
                ) {
                  sh """
                    kubectl get pods -l version=${verifyEnv} -n ${KUBE_NAMESPACE}
                    kubectl get svc bankapp-service -n ${KUBE_NAMESPACE}
                  """
                }
              }
            }
          }
        }
    }
}
