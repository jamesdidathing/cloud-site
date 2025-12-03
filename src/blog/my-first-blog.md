---
title: "Building a Serverless Cloud Resume"
description: "How I built my resume website using AWS, Terraform, and GitHub Actions"
date: 2025-12-02
tags: 
  - aws
  - terraform
  - devops
---

## Why bother?

Personally, I relocated to Australia for my partners job so I had to put a pause on my job in the UK and go on a career break. Now - most would think this is a great time to just relax, chill out and not do any "work" for a while. Unfortunately though, my brain doesn't allow that and years of educational stress means I feel like I should always be doing *something*...

So how can someone keep advancing their career, when on a break from it?

I decided to upskill myself! One thing I find with learning on the job, is that you only ever learn the things you need for the job you are doing, and nothing else. What if I want to use a new technology? I need to find something that my job wants, and then I can go and learn it after.

One thing I have always been interested in learning is ___Cloud Technology___. A scary, new and quite abstract thing to me at the time I started, and something that if done wrong can really rack up a credit bill. A great way to learn! 

This post is all about my journey through the [Cloud Resume Challenge](https://cloudresumechallenge.dev/docs/the-challenge/aws/_), and I would advocate anyone wanting to learning the same things to take part. This post isn't going to talk about the intricate details of how each part works and how I set it up (there's hundreds of those), but more of what my experience was like through all of this and what I learned throughout.


## The Architecture

Let's see a nice diagram of what we made:

![AWS Architecture](/images/AWS.drawio.svg)

The run down:

**Frontend**: My resume site is a static website hosted on S3, served globally through CloudFront with SSL from AWS Certificate Manager. Route 53 handles the DNS for my custom domain.

**Backend**: A visitor counter powered by API Gateway, Lambda functions, and DynamoDB. Every page visit increments the counter and triggers an event-driven data pipeline.

**Analytics**: EventBridge routes visitor events to a second Lambda function that writes them to an S3 data lake. AWS Glue crawls this data, and Athena lets me run SQL queries to analyse traffic patterns.

The entire infrastructure is managed with Terraform, and GitHub Actions handles continuous deployment.


## Some Problems I Had

### CloudFront Caching vs Real-Time Updates

**The Problem**: When it came to creating some tests for my website and its functions, I found that the visitor counter was causing them to fail. It turns out that CloudFront was caching it's response for 60 seconds, meaning if you refreshed within this time frame - it would not update the counter! This was mainly a problem for my tests, but also made the website feel a bit broken.

**The Solution**: I had to balance performance with freshness. After testing, I settled on a 15-second cache - short enough to feel responsive, long enough to reduce Lambda costs and fix my tests. I had to adjust my tests to allow for this refresh to take place.


### Challenge 2: Moving from Console to Infrastructure as Code

**The Problem**: Working through the challenge, it starts with just using the AWS Console (click buttons on a UI). This was great for learning and seeing what I was actually doing, but what happens if I need to share what I have done? What if we need to version control the settings we've used? 

**The Solution**: This is where we use Infrastructure as Code with a tool such as **Terraform**. I had to import every resource we used - S3 buckets, Lambda functions, API Gateway, CloudFront distribution, Route 53 records, and more.  Each resource type had different import syntax. It took __HOURS__ of careful work, but in the end it was worth it. Once set up, we could implement new changes really easily and redeploy. Even better, we can version control it.

**Lesson Learned**: Start with Infrastructure as Code from day one. Migrating later is painful. But doing it taught me how Terraform state management works at a deep level.



### Challenge 5: Python Dependency Management

**The Problem**: I started with pip and requirements.txt (for my own ease, bigger projects I would not start with this), but managing dependencies across local development, CI/CD, and Lambda deployment was messy. Different environments had different package versions. 

**The Solution**: I migrated to `uv` and `pyproject.toml`. This gave me proper dependency separation (production vs dev), lockfiles for reproducibility, and much faster installs. The `uv.lock` file ensures everyone gets identical package versions. I'm a big fan of `uv` and have used it quite a lot in my career, so this was always going to be the solution.

**Lesson Learned**: Modern Python tooling makes a huge difference (especially ones written in Rust). Invest time in proper dependency management early - it pays off in reliability and team collaboration.


### Challenge 5: Enriched Metadata

**The Problem**: Towards the end of the challenge, I decided to introduce some Python pipelines for extracting and analysing the visitor event data I was collecting. I quickly realised this was not working as intended though, one of the main stats I wanted to track was **where** my vistors were visiting from. The approach I originally used was not getting this data though. I wanted to fix this, but also include some more metadata to each visit which I might find useful.

**The Solution**: I used the IP of each visit to gather more data, like the country, ISP and even the city. Obviously this data can be skewed (VPN's exist) but it's a good indication generally of where the visits are coming from. Especially if I apply for a job, I can see if I get a visit from the city the job is in! This data is never shared and is only used for myself.

**Lesson Learned**: Metadata enrichment is a great approach for a more data engineering pipeline, and there are tons of tools out there to use to help with this.  


## What I Built

The final system includes:

- **Static website** built with Eleventy and deployed to S3
- **Visitor counter** with DynamoDB persistence and API Gateway caching
- **Event-driven analytics pipeline** capturing every page view
- **Data lake** in S3 with partitioned storage for efficient querying
- **SQL analytics** via Athena to understand traffic patterns
- **Complete CI/CD** with GitHub Actions for testing and deployment
- **Infrastructure as Code** using Terraform for all AWS resources
- **Comprehensive testing** - unit tests with pytest/moto, E2E tests with Playwright
- **Code quality** checks with Ruff linting and formatting

## Technologies I Learned

**AWS Services**: S3, CloudFront, Route 53, API Gateway, Lambda, DynamoDB, EventBridge, Glue, Athena, ACM, CloudWatch, IAM

**Infrastructure**: Terraform for resource management, AWS Organizations for multi-account setup, IAM Identity Center for SSO

**Development**: Python with boto3 for Lambda, JavaScript for frontend, Eleventy for static site generation

**DevOps**: GitHub Actions for CI/CD, pytest and Playwright for testing, Ruff for linting

**Tools**: uv for Python dependencies, AWS CLI with SSO profiles, Terraform CLI

## Key Lessons

### 1. Serverless Isn't Always Cheaper, But It Scales Better
My entire infrastructure costs $1-2/month because of AWS free tier. But the real value is scalability - if my site suddenly got 10,000 visitors, it would handle it without any changes. Traditional hosting would require manual intervention.

### 2. Infrastructure as Code Is Non-Negotiable
Being able to `terraform apply` and rebuild my entire infrastructure in minutes is incredibly powerful. It's also documentation - anyone can read my Terraform files and understand exactly what's deployed.

### 3. Observability Matters From Day One
Building the analytics pipeline taught me the value of instrumentation. I can now see traffic patterns, understand user behavior, and debug issues. 

### 4. CI/CD Saves Time and Reduces Errors
Pushing to GitHub and having tests run automatically, then deploying if they pass, is game-changing. No more "did I remember to invalidate the CloudFront cache?" mistakes.

### 5. Real Production Experience Is Different Than Tutorials
Tutorials show happy paths. Real projects involve CORS debugging, cache invalidation strategies, test flakiness, dependency conflicts, and state management. This project gave me production-level experience which I can use in the future.


## Try It Yourself

The [Cloud Resume Challenge](https://cloudresumechallenge.dev/) is an excellent way to learn cloud technologies hands-on. Don't just follow tutorials - build something real, face real problems, and learn how production systems actually work.

My advice: Start simple, but build it properly. Use IaC from day one, write tests, set up CI/CD, and add observability. These aren't "nice-to-haves" - they're how real cloud applications are built.


**Update**: This post is part of my learning journey in cloud engineering. Follow my progress as I continue building and documenting!