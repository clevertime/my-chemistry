import os
import time
from decimal import Decimal
import json
import logging
import boto3

# globals
dynamodb = boto3.resource('dynamodb')

# create record in dynamo
def create_record(table, data):

    logging.info("[*] posting record to dynamo: %s", table)
    transformed_data = json.loads(json.dumps(data), parse_float=Decimal)
    dynamo_table = dynamodb.Table(table)
    response = dynamo_table.put_item(
        Item=transformed_data
    )

    return response

def get_timestamp():
    return time.time()

def handler(event, context):

    # get data
    try:
        data = json.loads(event['body'])['data']
    except:
        logging.error("[!] incorrect request body format")
        return {"statusCode": 400, "body": json.dumps("incorrect request body format")}

    # calculate timestamp if not provided
    if 'timestamp' not in data.keys():
        data['timestamp'] = get_timestamp()

    # create record
    response      = create_record(os.environ['TABLE_NAME'], data)
    status_code   = response['ResponseMetadata']['HTTPStatusCode']
    return {"statusCode": status_code, "body": json.dumps(response)}
