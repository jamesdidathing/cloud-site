import json
from datetime import datetime

import boto3

# Initialize S3 client
s3 = boto3.client("s3")

# Your S3 bucket name
BUCKET_NAME = "james-cloud-resume-events"


def lambda_handler(event, context):
    """
    This function is triggered by EventBridge.
    It receives enriched events and writes them to S3.
    """

    try:
        # PART 1: Extract event detail
        # =============================

        # EventBridge wraps our event in a standard format
        # Our enriched event is in the 'detail' field
        detail = event["detail"]

        # PART 2: Create partitioned path
        # ================================

        # Partitioning organises data by date for efficient querying

        # Parse the timestamp from the event
        timestamp = datetime.fromisoformat(detail["timestamp"])

        # Extract date components
        year = timestamp.strftime("%Y")
        month = timestamp.strftime("%m")
        day = timestamp.strftime("%d")
        hour = timestamp.strftime("%H")

        file_name = (
            f"events/year={year}/month={month}/day={day}/hour={hour}/{context.aws_request_id}.json"
        )

        # PART 3: Write to S3
        # ====================

        s3.put_object(
            Bucket=BUCKET_NAME,
            Key=file_name,
            Body=json.dumps(detail),
            ContentType="application/json",
        )
        print(f"Event written to s3://{BUCKET_NAME}/{file_name}")

        return {"statusCode": 200, "body": json.dumps("Event stored successfully")}

    except Exception as e:
        print(f"Error writing to S3: {str(e)}")
        raise  # Re-raise the exception so EventBridge knows it failed
