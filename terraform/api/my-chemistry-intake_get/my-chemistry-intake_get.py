""" function to query records from dynamodb """
import os
import json
import logging
import boto3
from boto3.dynamodb.conditions import Key

# globals
dynamodb = boto3.resource('dynamodb')

# create record in dynamo
def get_user_records(table, user):
    """ get record based on user field """

    logging.info("[*] getting records from dynamo: %s", table)
    dynamo_table = dynamodb.Table(table)
    response = dynamo_table.query(
        KeyConditionExpression=Key('user').eq(user)
    )

    return response

def handler(event, context):
    """ main handler """
    logging.info("[*] context: %s", context)
    # get data
    try:
        data = json.loads(event['body'])['data']
    except KeyError:
        logging.error("[!] incorrect request body format")
        response = {"statusCode": 400, "body": json.dumps("[!] incorrect request body format")}
        return response

    # get user records if provided
    if 'user' in data.keys():
        records = get_user_records(os.environ['TABLE_NAME'], data['user'])
        status_code = records['ResponseMetadata']['HTTPStatusCode']
        response = {"statusCode": status_code, "body": json.dumps(response)}
        return response

	# return full table
    response = json.dumps("placeholder")
    return response
