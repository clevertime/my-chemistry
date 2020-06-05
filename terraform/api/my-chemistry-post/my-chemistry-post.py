import boto3
import json
import logging
import os
import time
from decimal import Decimal

# globals
dynamodb = boto3.resource('dynamodb')

# create record in dynamo
def create_record(table, data):

    logging.info("[*] posting record to dynamo: " + table)
    transformed_data = json.loads(json.dumps(data), parse_float=Decimal)
    dynamo_table = dynamodb.Table(table)
    response = dynamo_table.put_item(
        Item=transformed_data
    )

def get_timestamp():
    return time.time()

def handler (event, context):

    # get data
	data = event['data']

    # calculate timestamp if not provided
	if 'timestamp' not in data.keys():
	    data['timestamp'] = get_timestamp()

    # create record
	create_record(os.environ['TABLE_NAME'], event['data'])

    return {
        "statusCode": 200,
        "body": json.dumps('Cheers from AWS Lambda!!')
    }
