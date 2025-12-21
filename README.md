# Cloud Resume Challenge

A serverless resume website built on AWS Cloud, with automatic deployment with GitHub Actions. Using Terraform, we have created Infrastructure as Code (IaC) for automatic service management.

![deploy workflow](https://github.com/jamesdidathing/cloud-site/actions/workflows/deploy.yml/badge.svg)
![push workflow](https://github.com/jamesdidathing/cloud-site/actions/workflows/push.yml/badge.svg)


## Live Site

Visit: [https://james-hodson.com](https://james-hodson.com)

## Architecture

- **Frontend**: Static site hosted on S3, delivered via CloudFront
- **Backend**: Serverless API using API Gateway and Lambda (Python)
- **Database**: DynamoDB for visitor count storage
- **DNS & SSL**: Route 53 and AWS Certificate Manager
- **Analytics**: CloudFront logs analyzed with AWS Glue and Athena

## Technologies

- **Static Site Generator**: Eleventy (11ty)
- **Cloud Provider**: AWS
- **Infrastructure**: S3, CloudFront, Route 53, API Gateway, Lambda, DynamoDB, GitHub Actions
- **Languages**: HTML, CSS, JavaScript, Python
- **Analytics**: AWS Glue, Athena

## Pre-requisites

- **Python 3.12+**
- **Node.js 18+**
- **AWS CLI** with SSO configured
- **Terraform 1.0+**
- **uv** 

## Quick Start

### 1. Clone the Repository
```bash
git clone git@github.com:jamesdidathing/cloud-site.git
cd cloud-site
```

### 2. Install uv

Homebrew:
```bash
brew install uv
```

### 3. Set Up Python Environment
```bash
# Install Python (if not already installed)
uv python install 3.12

# Create virtual environment and install dependencies
uv sync --all-extras

# Activate the environment
source .venv/bin/activate  # macOS/Linux
```

### 4. Install Node.js Dependencies
```bash
npm install
```

## Running Tests

### Unit Tests
```bash
# Run Lambda function unit tests
uv run pytest tests/test_lambda.py -v
```

### End-to-End Tests
```bash
# Install Playwright browsers (first time only)
uv run playwright install chromium

# Run E2E tests
uv run pytest tests/test_website.py -v
```

## CI/CD Pipeline

### Workflows

**On every push to main/develop:**
- ✅ Run unit tests
- ✅ Lint with Ruff
- ✅ Type checking with Ty
- ✅ Check code formatting

**Manual deployment trigger:**
- ✅ Run all tests
- ✅ Build Eleventy site
- ✅ Deploy to S3
- ✅ Invalidate CloudFront
- ✅ Run E2E tests

## Project Structure
```
.
├── .github/
│   └── workflows/          # CI/CD workflows
├── lambda/
│   ├── visitor_counter.py  # Visitor counter Lambda
│   └── event_writer.py     # S3 event writer Lambda
├── terraform/
│   ├── main.tf            # Infrastructure definitions
│   ├── variables.tf       # Input variables
│   ├── outputs.tf         # Output values
│   └── cloudfront-function.js
├── tests/
│   ├── test_lambda.py     # Unit tests
│   └── test_website.py    # E2E tests
├── src/                   # Eleventy source files
├── pyproject.toml         # Python dependencies & config
├── uv.lock               # Dependency lockfile
├── package.json          # Node.js dependencies
└── .eleventy.js          # Eleventy configuration
```

Built as part of the [Cloud Resume Challenge](https://cloudresumechallenge.dev/)
