import boto3
import json

# Initialize DynamoDB client
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('visitor-count') 

def lambda_handler(event, context):
    """
    Increment and return the visitor count
    """
    
    try:
        # Get the current count
        response = table.get_item(
            Key={'id': 'visitor-count'}
        )
        
        # Check if item exists
        if 'Item' not in response:
            # If item doesn't exist, create it
            table.put_item(
                Item={
                    'id': 'visitor-count',
                    'count': 0
                }
            )
            count = 0
        else:
            count = int(response['Item']['count'])
        
        # Increment count
        new_count = count + 1
        
        # Update in DynamoDB
        table.update_item(
            Key={'id': 'visitor-count'}, 
            UpdateExpression='SET #count = :val',
            ExpressionAttributeNames={'#count': 'count'},
            ExpressionAttributeValues={':val': new_count}
        )
        
        # Return proper API Gateway response
        return {
            'statusCode': 200,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Content-Type': 'application/json'
            },
            'body': json.dumps({'count': new_count})
        }
        
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Content-Type': 'application/json'
            },
            'body': json.dumps({'error': str(e)})
        }