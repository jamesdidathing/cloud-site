terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
  
  default_tags {
    tags = {
      Project   = "CloudResume"
      ManagedBy = "Terraform"
    }
  }
}

# ==========================================
# S3 BUCKETS
# ==========================================

# Website bucket
resource "aws_s3_bucket" "resume_bucket" {
  bucket = "james-cloud-resume"
}

resource "aws_s3_bucket_public_access_block" "resume_bucket" {
  bucket = aws_s3_bucket.resume_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Events bucket (data lake)
resource "aws_s3_bucket" "events_bucket" {
  bucket = "james-cloud-resume-events"
}

resource "aws_s3_bucket_public_access_block" "events_bucket" {
  bucket = aws_s3_bucket.events_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Logs bucket
resource "aws_s3_bucket" "logs_bucket" {
  bucket = "james-cloud-resume-logs"
}

resource "aws_s3_bucket_public_access_block" "logs_bucket" {
  bucket = aws_s3_bucket.logs_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ==========================================
# DYNAMODB
# ==========================================

resource "aws_dynamodb_table" "visitor_count" {
  name           = "visitor-count"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = {
    Purpose = "Visitor counter for cloud resume"
  }
}

# ==========================================
# IAM ROLES AND POLICIES
# ==========================================

# Role for Event Ingestion Lambda
resource "aws_iam_role" "event_ingestion_lambda_role" {
  name = "event-ingestion-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Update the EventBridge permission in event_ingestion_lambda_policy
resource "aws_iam_role_policy" "event_ingestion_lambda_policy" {
  name = "event-ingestion-lambda-policy"
  role = aws_iam_role.event_ingestion_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem"
        ]
        Resource = aws_dynamodb_table.visitor_count.arn
      },
      {
        Effect = "Allow"
        Action = [
          "events:PutEvents"
        ]
        Resource = aws_cloudwatch_event_bus.visitor_events.arn  # Updated!
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:*:*"
      }
    ]
  })
}

# Role for Event Writer Lambda
resource "aws_iam_role" "event_writer_lambda_role" {
  name = "event-writer-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Policy for Event Writer Lambda
resource "aws_iam_role_policy" "event_writer_lambda_policy" {
  name = "event-writer-lambda-policy"
  role = aws_iam_role.event_writer_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.events_bucket.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:*:*"
      }
    ]
  })
}

# ==========================================
# LAMBDA FUNCTIONS
# ==========================================

# Event Ingestion Lambda (visitor counter)
resource "aws_lambda_function" "visitor_counter" {
  filename         = "visitor_counter.zip"
  function_name    = "VisitorCounterFunction"
  role            = aws_iam_role.event_ingestion_lambda_role.arn
  handler         = "visitor_counter.lambda_handler"
  runtime         = "python3.12"
  source_code_hash = filebase64sha256("visitor_counter.zip")
  timeout         = 10

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.visitor_count.name
      EVENT_BUS_NAME = "visitor-events"  # We'll create this next
    }
  }
}

# Event Writer Lambda
resource "aws_lambda_function" "event_writer" {
  filename         = "event_writer.zip"
  function_name    = "EventWriterFunction"
  role            = aws_iam_role.event_writer_lambda_role.arn
  handler         = "event_writer.lambda_handler"
  runtime         = "python3.12"
  source_code_hash = filebase64sha256("event_writer.zip")
  timeout         = 10

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.events_bucket.bucket
    }
  }
}

# ==========================================
# EVENTBRIDGE
# ==========================================

# Custom event bus
resource "aws_cloudwatch_event_bus" "visitor_events" {
  name = "visitor-events"
}

# Event rule to route page views to S3
resource "aws_cloudwatch_event_rule" "visitor_event_to_s3" {
  name           = "visitor-event-to-s3"
  event_bus_name = aws_cloudwatch_event_bus.visitor_events.name

  event_pattern = jsonencode({
    source      = ["visitor-counter"]
    detail-type = ["PageView"]
  })
}

# Target: Event Writer Lambda
resource "aws_cloudwatch_event_target" "event_writer" {
  rule           = aws_cloudwatch_event_rule.visitor_event_to_s3.name
  event_bus_name = aws_cloudwatch_event_bus.visitor_events.name
  arn            = aws_lambda_function.event_writer.arn
}

# Permission for EventBridge to invoke Event Writer Lambda
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.event_writer.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.visitor_event_to_s3.arn
}

# ==========================================
# API GATEWAY
# ==========================================

# REST API
resource "aws_api_gateway_rest_api" "visitor_counter_api" {
  name        = "VisitorCounterAPI"
  description = "API for visitor counter"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

# /count resource
resource "aws_api_gateway_resource" "count" {
  rest_api_id = aws_api_gateway_rest_api.visitor_counter_api.id
  parent_id   = aws_api_gateway_rest_api.visitor_counter_api.root_resource_id
  path_part   = "count"
}

# GET method on /count
resource "aws_api_gateway_method" "count_get" {
  rest_api_id   = aws_api_gateway_rest_api.visitor_counter_api.id
  resource_id   = aws_api_gateway_resource.count.id
  http_method   = "GET"
  authorization = "NONE"
}

# Lambda integration for GET
resource "aws_api_gateway_integration" "count_get_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.visitor_counter_api.id
  resource_id             = aws_api_gateway_resource.count.id
  http_method             = aws_api_gateway_method.count_get.http_method
  integration_http_method = "POST"  # Lambda always uses POST
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.visitor_counter.invoke_arn
}

# CORS configuration - OPTIONS method
resource "aws_api_gateway_method" "count_options" {
  rest_api_id   = aws_api_gateway_rest_api.visitor_counter_api.id
  resource_id   = aws_api_gateway_resource.count.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "count_options" {
  rest_api_id = aws_api_gateway_rest_api.visitor_counter_api.id
  resource_id = aws_api_gateway_resource.count.id
  http_method = aws_api_gateway_method.count_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "count_options" {
  rest_api_id = aws_api_gateway_rest_api.visitor_counter_api.id
  resource_id = aws_api_gateway_resource.count.id
  http_method = aws_api_gateway_method.count_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "count_options" {
  rest_api_id = aws_api_gateway_rest_api.visitor_counter_api.id
  resource_id = aws_api_gateway_resource.count.id
  http_method = aws_api_gateway_method.count_options.http_method
  status_code = aws_api_gateway_method_response.count_options.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

# Deployment
resource "aws_api_gateway_deployment" "prod" {
  rest_api_id = aws_api_gateway_rest_api.visitor_counter_api.id

  # Force new deployment on any change
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.count.id,
      aws_api_gateway_method.count_get.id,
      aws_api_gateway_integration.count_get_lambda.id,
      aws_api_gateway_method.count_options.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.count_get_lambda,
    aws_api_gateway_integration.count_options,
  ]
}

# Stage
resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.prod.id
  rest_api_id   = aws_api_gateway_rest_api.visitor_counter_api.id
  stage_name    = "prod"
}

# Lambda permission for API Gateway
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.visitor_counter.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.visitor_counter_api.execution_arn}/*/*"
}

# ==========================================
# AWS GLUE
# ==========================================

# Glue database
resource "aws_glue_catalog_database" "visitor_events" {
  name = "visitor_events_db"
}

# IAM role for Glue crawler
resource "aws_iam_role" "glue_crawler_role" {
  name = "glue-crawler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
      }
    ]
  })
}

# Attach AWS managed policy for Glue
resource "aws_iam_role_policy_attachment" "glue_service" {
  role       = aws_iam_role.glue_crawler_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# Policy for S3 access
resource "aws_iam_role_policy" "glue_s3_policy" {
  name = "glue-s3-policy"
  role = aws_iam_role.glue_crawler_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.events_bucket.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.events_bucket.arn
      }
    ]
  })
}

# Glue crawler
resource "aws_glue_crawler" "visitor_events_crawler" {
  name          = "visitor-events-crawler"
  role          = aws_iam_role.glue_crawler_role.arn
  database_name = aws_glue_catalog_database.visitor_events.name

  s3_target {
    path = "s3://${aws_s3_bucket.events_bucket.bucket}/events/"
  }

  schema_change_policy {
    delete_behavior = "LOG"
    update_behavior = "UPDATE_IN_DATABASE"
  }

  configuration = jsonencode({
    Version = 1.0
    CrawlerOutput = {
      Partitions = {
        AddOrUpdateBehavior = "InheritFromTable"
      }
    }
  })
}

# CloudFront logs database
resource "aws_glue_catalog_database" "cloudfront_logs" {
  name = "cloudfront_logs_db"
}

# ==========================================
# CLOUDFRONT
# ==========================================

# Origin Access Control for S3
resource "aws_cloudfront_origin_access_control" "resume_bucket" {
  name                              = "resume-bucket-oac"
  description                       = "OAC for resume S3 bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront function for URL rewriting
resource "aws_cloudfront_function" "url_rewrite" {
  name    = "url-rewrite"
  runtime = "cloudfront-js-1.0"
  comment = "Rewrite URLs to add index.html"
  publish = true
  code    = file("${path.module}/cloudfront-function.js")
}

# CloudFront distribution
resource "aws_cloudfront_distribution" "resume_distribution" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  price_class         = "PriceClass_100"  # Use only North America & Europe
  aliases             = [var.domain_name]

  # S3 origin
  origin {
    domain_name              = aws_s3_bucket.resume_bucket.bucket_regional_domain_name
    origin_id                = "S3-${aws_s3_bucket.resume_bucket.bucket}"
    origin_access_control_id = aws_cloudfront_origin_access_control.resume_bucket.id
  }

  # API Gateway origin
  origin {
    domain_name = replace(aws_api_gateway_stage.prod.invoke_url, "/^https?://([^/]*).*/", "$1")
    origin_id   = "API-Gateway"
    origin_path = "/prod"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # Default cache behavior (S3 content)
  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-${aws_s3_bucket.resume_bucket.bucket}"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.url_rewrite.arn
    }

    min_ttl     = 0
    default_ttl = 86400
    max_ttl     = 31536000
  }

  # Cache behavior for /count endpoint (GET - cached)
  ordered_cache_behavior {
    path_pattern           = "/count"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "API-Gateway"
    viewer_protocol_policy = "https-only"
    compress               = true

    forwarded_values {
      query_string = false
      headers      = ["Origin", "CloudFront-Viewer-Country", "CloudFront-Viewer-Country-Region"]
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
  }

  # Custom error responses
  custom_error_response {
    error_code         = 500
    response_code      = 200
    response_page_path = "/index.html"
  }

  custom_error_response {
    error_code         = 502
    response_code      = 200
    response_page_path = "/index.html"
  }

  custom_error_response {
    error_code         = 503
    response_code      = 200
    response_page_path = "/index.html"
  }

  custom_error_response {
    error_code         = 504
    response_code      = 200
    response_page_path = "/index.html"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = var.acm_certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  logging_config {
    bucket = aws_s3_bucket.logs_bucket.bucket_domain_name
    prefix = "cloudfront/"
  }

  tags = {
    Name = "CloudResume Distribution"
  }
}

# S3 bucket policy to allow CloudFront
resource "aws_s3_bucket_policy" "resume_bucket" {
  bucket = aws_s3_bucket.resume_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.resume_bucket.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.resume_distribution.arn
          }
        }
      }
    ]
  })
}

# ==========================================
# ROUTE 53
# ==========================================

# Get existing hosted zone (you already have this)
data "aws_route53_zone" "main" {
  name         = var.domain_name
  private_zone = false
}

# A record pointing to CloudFront
resource "aws_route53_record" "root" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.resume_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.resume_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}

# AAAA record (IPv6) pointing to CloudFront
resource "aws_route53_record" "root_ipv6" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.resume_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.resume_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}