
# 'Mini' Continuous Integration/Continuous Delivery (CI/CD) Pipeline

## 1. Introduction

This README describes the implementation of an automated Continuous Integration/Continuous Delivery (CI/CD) pipeline for a simple **Node.js** application (Hello, world!).  

The infrastructure is provisioned using **Terraform**, and the deployment process is orchestrated via **GitHub Actions**, utilizing **OpenID Connect (OIDC)** for secure, role-based authorization with **Amazon Web Services (AWS)**.  

The target deployment platform is **Amazon Elastic Container Service (ECS) Fargate**, with **AWS CloudWatch** integrated for centralized logging and monitoring.

---

## 2. Infrastructure and Architecture

### 2.1 Key Technologies

| Category | Technology | Role in Project |
| :--- | :--- | :--- |
| **Infrastructure-as-Code (IaC)** | **Terraform** | Provisioning of the ECS Cluster, Elastic Container Registry (ECR), IAM Roles, and Task Definition. |
| **CI/CD Orchestration** | **GitHub Actions** | Manages automated workflow steps: testing, code quality checks, container build, and deployment. |
| **Containerization** | **Docker** | Creates a portable, versioned application image using a multi-stage build pattern. |
| **Deployment Target** | **AWS ECS Fargate** | Serverless platform hosting the application service (`node-app-service`). |
| **Security** | **AWS OIDC** | Provides secure, ephemeral credential exchange for GitHub Actions to interact with AWS. |
| **Observability** | **AWS CloudWatch** | Central repository for application logs and infrastructure metrics. |

---

### 2.2 Architectural Flow Diagram

The pipeline follows a [**GitOps**](https://www.bmc.com/blogs/gitops-cloud-native-app-delivery/) model, ensuring full automation and traceability from code commit to service runtime.

```text
+-----------------+   (1) Code Commit    +-------------------+
|   Developer     | -------------------> | GitHub Repository |
+-----------------+                      +-------------------+
                                                    |
                                                    v
+---------------------------------------------------------------------------------------------------------+
|        GitHub Actions Workflow (.github/workflows/ci-pipeline.yml)                                      |
+---------------------------------------------------------------------------------------------------------+
|  (2) CI: Pull Request                     |   (3) CD: Push to 'develop'                                 |
|  ---------------------------------------- |  -----------------------------------------------------------|
|  - Unit Testing (Jest)                    |  - OIDC Role Assumption                                     |
|  - Static Analysis (ESLint)               |  - Docker Build, Tag (SHA), Push to ECR                     |
|  - Security Scanning                      |  - ECS Deployment: Update ECS Service with new Task Revision|
+---------------------------------------------------------------------------------------------------------+
        |
        v
+----------------+       (4) Image Pull       +-----------------+       (5) Runtime      +----------------+
|    AWS ECR     | -------------------------> | AWS ECS Fargate | ---------------------> | AWS CloudWatch |
|(Image Registry)|                            |(Cluster/Service)|                        |(Logs & Metrics)|
+----------------+                            +-----------------+                        +----------------+
````

---

## 3. Implementation and Execution

### 3.1 Prerequisites and Local Environment

To use this CI/CD pipeline, ensure the following components are installed locally:

* **Git**
* **Node.js / npm**
* **Docker Engine**
* **Terraform CLI** (v1.0 or later)
* **AWS CLI** (configured with credentials for IAM/Terraform)

---

### 3.2 Infrastructure Provisioning (Terraform)

All infrastructure code is defined in the `terraform/` directory.

0. **change directory** into `terraform/`:
   ```bash
   cd terraform
   ```

1. **Initialize Terraform:**

   ```bash
   terraform init
   ```

2. **Apply Configuration:**

   ```bash
   terraform apply
   ```

   This provisions the ECS Cluster, ECR Repository, and required IAM roles (e.g., `ecs-task-execution-role`).

3. **Post-Provisioning Configuration:**
   Manually create the **ECS Service** (`node-app-service`) in the AWS Console, referencing:

   * The provisioned **Cluster**
   * The **Task Definition** (`node-app-task`)
   * **VPC Subnets**
   * **Security Group** (allowing inbound traffic on port `3000`)

---

### 3.3 CI/CD Workflow Summary

The unified GitHub Actions workflow (`.github/workflows/ci-pipeline.yml`) manages all automation stages.

| Job                              | Trigger           | Key AWS Actions                                 | Output                                     |
| :------------------------------- | :---------------- | :---------------------------------------------- | :----------------------------------------- |
| **Continuous Integration**       | Pull Request      | N/A                                             | Pass/Fail status for merge readiness       |
| **Continuous Delivery (Step 1)** | Push to `develop` | `aws-actions/configure-aws-credentials`         | Updated ECS Service credentials            |
| **Continuous Delivery (Step 2)** | Push to `develop` | `aws-actions/amazon-ecs-deploy-task-definition` | Deployed ECS Task & stability confirmation |

---

## 4. Verification and Testing Procedures

Functional verification involves triggering the pipeline with a controlled code change.

1. **Isolate Code Change:**

   ```bash
   git checkout -b feature/verification
   ```

2. **Trigger CI:**
   Submit a Pull Request to the `develop` branch. Verify all CI checks (**Test**, **Lint**, **Scan**) complete successfully.

3. **Trigger CD:**
   Merge the PR into `develop`. Monitor GitHub Actions to confirm successful deployment.

4. **Endpoint Validation:**

   * Go to **AWS ECS Console → Tasks → node-app-service**
   * Retrieve the **Public IP Address** of the running Fargate Task
   * Access the app in your browser:

     ```
     http://<Public-IP-Address>:3000
     ```

**Verification Criterion:**
The app should display the latest code changes, confirming successful artifact flow from **GitHub → ECR → ECS Fargate**.

---

## 5. Dependencies and Setup

### Initialize and Install Dependencies

```bash
npm init -y
npm install express
npm install jest supertest --save-dev
npm install eslint --save-dev
npx eslint --init
npm install --save-dev eslint-plugin-node eslint-plugin-jest
```

During ESLint setup:

```
✔ What do you want to lint? · javascript
✔ How would you like to use ESLint? · problems
✔ What type of modules does your project use? · commonjs
✔ Which framework does your project use? · none
✔ Does your project use TypeScript? · No
✔ Where does your code run? · node
✔ Would you like to install required dependencies now? · Yes
✔ Which package manager do you want to use? · npm
```

Then, install additional plugins:

```bash
npm install eslint-plugin-jest --save-dev
```

---

### Docker Installation

```bash
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

---

**Author:** Andrea Rossolini
