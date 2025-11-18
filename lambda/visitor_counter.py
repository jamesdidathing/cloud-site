import json
from datetime import datetime

import boto3

# Initialize AWS service clients
eventbridge = boto3.client("events")  # For sending events
dynamodb = boto3.resource("dynamodb")  # For the visitor counter
table = dynamodb.Table("visitor-count")  # Your DynamoDB table

# Name of the EventBridge bus we create
EVENT_BUS_NAME = "visitor-events"


def lambda_handler(event, context):
    """
    This function runs every time someone visits the website.

    It does three things:
    1. Enriches the event with useful metadata
    2. Sends the enriched event to EventBridge
    3. Increments the visitor counter in DynamoDB
    """

    try:
        # PART 1: Extract information from the request
        # =============================================

        # API Gateway passes request details in requestContext
        request_context = event.get("requestContext", {})

        # Identity contains visitor information (IP, user agent, etc.)
        identity = request_context.get("identity", {})

        # PART 2: Enrich the event with metadata
        # ========================================
        enriched_event = {
            "timestamp": datetime.utcnow().isoformat(),
            "event_type": "page_view",  # Could be 'button_click', 'form_submit'
            "source_ip": identity.get("sourceIp", "unknown"),  # Visitor's IP address
            "user_agent": identity.get("userAgent", "unknown"),  # Browser info
            "request_id": context.aws_request_id,  # Unique ID for this Lambda invocation
            "domain": request_context.get("domainName", "unknown"),  # Your domain
            "path": request_context.get(
                "path", "/"
            ),  # Which page (/about, /projects, etc.) (don't think this works atm)
            "http_method": request_context.get("httpMethod", "GET"),  # GET, POST, etc.
            "country": identity.get("country", "unknown"),  # Visitor's country
            "referer": event.get("headers", {}).get(
                "referer", "direct"
            ),  # Google, direct, etc.
        }

        # PART 3: Send event to EventBridge
        # ===================================

        # EventBridge.put_events() sends events to the event bus
        response = eventbridge.put_events(
            Entries=[
                {
                    # Source identifies where the event came from
                    "Source": "visitor-counter",
                    # DetailType categorizes the event
                    "DetailType": "PageView",
                    # Detail contains the actual event data (must be JSON string)
                    "Detail": json.dumps(enriched_event),
                    # Which event bus to send to
                    "EventBusName": EVENT_BUS_NAME,
                }
            ]
        )

        # PART 4: Update DynamoDB counter
        # =========================================================

        # Get current count from DynamoDB
        db_response = table.get_item(Key={"id": "visitor-count"})

        # Check if the item exists
        if "Item" not in db_response:
            table.put_item(Item={"id": "visitor-count", "count": 0})
            count = 0
        else:
            count = int(db_response["Item"]["count"])

        new_count = count + 1

        table.update_item(
            Key={"id": "visitor-count"},
            UpdateExpression="SET #count = :val",
            ExpressionAttributeNames={"#count": "count"},
            ExpressionAttributeValues={":val": new_count},
        )

        # PART 5: Return response to API Gateway
        # ========================================

        return {
            "statusCode": 200,
            "headers": {
                "Access-Control-Allow-Origin": "*",
                "Content-Type": "application/json",
            },
            "body": json.dumps(
                {
                    "count": new_count,  # Visitor counter (for website display)
                    "event_id": response["Entries"][0].get(
                        "EventId"
                    ),  # EventBridge event ID
                    "timestamp": enriched_event["timestamp"],
                }
            ),
        }

    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            "statusCode": 500,
            "headers": {
                "Access-Control-Allow-Origin": "*",
                "Content-Type": "application/json",
            },
            "body": json.dumps({"error": str(e)}),
        }
