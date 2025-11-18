import json
import sys
import os
from unittest.mock import Mock, patch, MagicMock

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "../lambda"))
sys.modules["boto3"] = MagicMock()

from visitor_counter import lambda_handler as ingestion_handler  # noqa: E402
from event_writer import lambda_handler as writer_handler  # noqa: E402

os.environ["AWS_DEFAULT_REGION"] = "us-east-1"


def test_ingestion_returns_200():
    """Test that Lambda returns success"""

    # Fake AWS context
    context = Mock()
    context.aws_request_id = "test-123"

    # Fake API Gateway event
    event = {
        "requestContext": {
            "identity": {"sourceIp": "1.2.3.4"},
            "domainName": "test.com",
            "path": "/",
            "httpMethod": "GET",
        },
        "headers": {},
    }

    # Mock AWS services so we don't call real AWS
    with patch("visitor_counter.eventbridge") as mock_eb, patch(
        "visitor_counter.table"
    ) as mock_table:
        # Set up fake responses
        mock_table.get_item.return_value = {
            "Item": {"id": "visitor-count", "count": 10}
        }
        mock_eb.put_events.return_value = {"Entries": [{"EventId": "123"}]}

        # Call the Lambda
        response = ingestion_handler(event, context)

        # Check it worked
        assert response["statusCode"] == 200
        assert "count" in json.loads(response["body"])


def test_database_actually_updates():
    """
    Verify database is actually updated, not just response returned
    """

    context = Mock()
    context.aws_request_id = "test-db-update"

    event = {
        "requestContext": {
            "identity": {},
            "domainName": "test.com",
            "path": "/",
            "httpMethod": "GET",
        },
        "headers": {},
    }

    with patch("visitor_counter.eventbridge") as mock_eb, patch(
        "visitor_counter.table"
    ) as mock_table:
        mock_table.get_item.return_value = {
            "Item": {"id": "visitor-count", "count": 42}
        }
        mock_eb.put_events.return_value = {"Entries": [{"EventId": "123"}]}

        # Call Lambda
        response = ingestion_handler(event, context)

        body = json.loads(response["body"])
        assert body["count"] == 43

        mock_table.update_item.assert_called_once()

        update_call = mock_table.update_item.call_args
        assert update_call[1]["Key"] == {"id": "visitor-count"}
        assert update_call[1]["ExpressionAttributeValues"] == {":val": 43}


def test_ingestion_increments_counter():
    """Test that counter goes up by 1"""

    context = Mock()
    context.aws_request_id = "test-456"

    event = {
        "requestContext": {
            "identity": {},
            "domainName": "test.com",
            "path": "/",
            "httpMethod": "GET",
        },
        "headers": {},
    }

    with patch("visitor_counter.eventbridge") as mock_eb, patch(
        "visitor_counter.table"
    ) as mock_table:
        mock_table.get_item.return_value = {
            "Item": {"id": "visitor-count", "count": 42}
        }
        mock_eb.put_events.return_value = {"Entries": [{"EventId": "123"}]}

        response = ingestion_handler(event, context)

        body = json.loads(response["body"])
        assert body["count"] == 43


def test_writer_saves_to_s3():
    """Test that event writer calls S3"""

    context = Mock()
    context.aws_request_id = "writer-123"

    # Fake EventBridge event
    event = {
        "detail": {
            "timestamp": "2025-11-10T14:23:45.123456",
            "event_type": "page_view",
            "source_ip": "1.2.3.4",
        }
    }

    with patch("event_writer.s3") as mock_s3:
        response = writer_handler(event, context)

        # Check it returned success
        assert response["statusCode"] == 200

        # Check it called S3
        mock_s3.put_object.assert_called_once()


def test_first_visitor_edge_case():
    """
    Edge case - very first visitor

    When no one has visited the site yet, DynamoDB has no item.
    Lambda should:
    1. Create the item with count=0
    2. Increment to 1
    3. Return 1
    """

    context = Mock()
    context.aws_request_id = "test-first-visitor"

    event = {
        "requestContext": {
            "identity": {},
            "domainName": "test.com",
            "path": "/",
            "httpMethod": "GET",
        },
        "headers": {},
    }

    with patch("visitor_counter.eventbridge") as mock_eb, patch(
        "visitor_counter.table"
    ) as mock_table:
        mock_table.get_item.return_value = {}  # No 'Item' key
        mock_eb.put_events.return_value = {"Entries": [{"EventId": "123"}]}

        response = ingestion_handler(event, context)

        body = json.loads(response["body"])
        assert body["count"] == 1

        mock_table.put_item.assert_called_once()
        put_call = mock_table.put_item.call_args
        assert put_call[1]["Item"] == {"id": "visitor-count", "count": 0}

        mock_table.update_item.assert_called_once()
        update_call = mock_table.update_item.call_args
        assert update_call[1]["ExpressionAttributeValues"] == {":val": 1}
