# Cloud Resume Challenge

A serverless resume website built on AWS Cloud.

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
- **Infrastructure**: S3, CloudFront, Route 53, API Gateway, Lambda, DynamoDB
- **Languages**: HTML, CSS, JavaScript, Python
- **Analytics**: AWS Glue, Athena

## Visitor Counter API

The visitor counter uses a serverless architecture:

1. JavaScript on the website calls API Gateway
2. API Gateway triggers Lambda function
3. Lambda reads current count from DynamoDB
4. Lambda increments count
5. Lambda saves new count to DynamoDB
6. Lambda returns count to frontend
7. JavaScript displays the count

## Project Structure
```
.
├── src/                    # Eleventy source files
│   ├── _includes/         # Layout templates
│   ├── css/               # Stylesheets
│   └── index.md           # Homepage content
├── lambda/                # Lambda function code
│   └── visitor_counter.py
├── .eleventy.js           # Eleventy configuration
├── package.json           # Node dependencies
└── README.md              # This file
```

## 🚀 Getting Started

### Prerequisites

- Node.js and npm
- AWS Account
- AWS CLI configured

### Local Development
```bash
# Install dependencies
npm install

# Run development server
npm start

# Build for production
npm run build
```

## 📜 License

This project is open source and available under the [MIT License](LICENSE).

## 🤝 Connect

- LinkedIn: [Your Profile]
- Twitter: [@yourhandle]
- Email: your.email@example.com

---

Built as part of the [Cloud Resume Challenge](https://cloudresumechallenge.dev/)