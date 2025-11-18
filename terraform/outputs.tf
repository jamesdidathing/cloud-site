output "website_bucket_name" {
  description = "Name of the website S3 bucket"
  value       = aws_s3_bucket.resume_bucket.bucket
}

output "events_bucket_name" {
  description = "Name of the events S3 bucket"
  value       = aws_s3_bucket.events_bucket.bucket
}

output "logs_bucket_name" {
  description = "Name of the logs S3 bucket"
  value       = aws_s3_bucket.logs_bucket.bucket
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB visitor count table"
  value       = aws_dynamodb_table.visitor_count.name
}

output "event_ingestion_lambda_arn" {
  description = "ARN of the event ingestion Lambda function"
  value       = aws_lambda_function.visitor_counter.arn
}

output "event_writer_lambda_arn" {
  description = "ARN of the event writer Lambda function"
  value       = aws_lambda_function.event_writer.arn
}

output "api_gateway_url" {
  description = "URL of the API Gateway"
  value       = "${aws_api_gateway_stage.prod.invoke_url}/count"
}

output "glue_database_name" {
  description = "Name of the Glue database for visitor events"
  value       = aws_glue_catalog_database.visitor_events.name
}

output "glue_crawler_name" {
  description = "Name of the Glue crawler"
  value       = aws_glue_crawler.visitor_events_crawler.name
}

variable "acm_certificate_arn" {
  description = "ARN of the ACM certificate (must be in us-east-1)"
  type        = string
}

output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution"
  value       = aws_cloudfront_distribution.resume_distribution.id
}

output "cloudfront_domain_name" {
  description = "Domain name of the CloudFront distribution"
  value       = aws_cloudfront_distribution.resume_distribution.domain_name
}

output "website_url" {
  description = "Full website URL"
  value       = "https://${var.domain_name}"
}