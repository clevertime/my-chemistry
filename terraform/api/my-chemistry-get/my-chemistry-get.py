import boto3
import json

def handler (event, context):
	return {
        "statusCode": 200,
        "body": json.dumps('Cheers from AWS Lambda!!')
    }
