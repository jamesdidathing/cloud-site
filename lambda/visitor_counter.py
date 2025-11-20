import json
import urllib.request
from datetime import datetime

import boto3

# Initialize AWS service clients
eventbridge = boto3.client("events")  # For sending events
dynamodb = boto3.resource("dynamodb")  # For the visitor counter
table = dynamodb.Table("visitor-count")  # Your DynamoDB table

# Name of the EventBridge bus we create
EVENT_BUS_NAME = "visitor-events"


def get_geolocation_data(ip_address):
    """Get geolocation data from IP address using ip-api.com"""
    if ip_address == "unknown" or not ip_address:
        return {
            "country": "unknown",
            "city": "unknown", 
            "isp": "unknown",
            "org": "unknown"
        }
    
    try:
        # Use ip-api.com free service (1000 requests per minute limit)
        url = f"http://ip-api.com/json/{ip_address}?fields=country,city,isp,org"
        with urllib.request.urlopen(url, timeout=2) as response:
            data = json.loads(response.read().decode())
            return {
                "country": data.get("country", "unknown"),
                "city": data.get("city", "unknown"),
                "isp": data.get("isp", "unknown"), 
                "org": data.get("org", "unknown")
            }
    except Exception:
        return {
            "country": "unknown",
            "city": "unknown",
            "isp": "unknown", 
            "org": "unknown"
        }


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
        source_ip = identity.get("sourceIp", "unknown")
        
        # Try CloudFront headers first, fallback to IP geolocation
        country = event.get("headers", {}).get("cloudfront-viewer-country")
        if not country or country == "unknown":
            geo_data = get_geolocation_data(source_ip)
            country = geo_data["country"]
            city = geo_data["city"]
            isp = geo_data["isp"]
            org = geo_data["org"]
        else:
            # If CloudFront provides country, still get other data from IP
            geo_data = get_geolocation_data(source_ip)
            city = geo_data["city"]
            isp = geo_data["isp"]
            org = geo_data["org"]
        
        enriched_event = {
            "timestamp": datetime.utcnow().isoformat(),
            "event_type": "page_view",  # Could be 'button_click', 'form_submit'
            "source_ip": source_ip,  # Visitor's IP address
            "user_agent": identity.get("userAgent", "unknown"),  # Browser info
            "request_id": context.aws_request_id,  # Unique ID for this Lambda invocation
            "domain": request_context.get("domainName", "unknown"),  # Your domain
            "path": request_context.get(
                "path", "/"
            ),  # Which page (/about, /projects, etc.) (don't think this works atm)
            "http_method": request_context.get("httpMethod", "GET"),  # GET, POST, etc.
            "country": country,  # Visitor's country
            "city": city,  # Visitor's city
            "isp": isp,  # Internet Service Provider
            "org": org,  # Organization
            "referer": event.get("headers", {}).get("referer", "direct"),  # Google, direct, etc.
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
                    "event_id": response["Entries"][0].get("EventId"),  # EventBridge event ID
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
