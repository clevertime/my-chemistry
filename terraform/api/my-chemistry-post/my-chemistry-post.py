import boto3
import json
import logging
import os

# globals
dynamodb = boto3.resource('dynamodb')

# create record in dynamo
def create_record(table, data):
    logging.info("[*] posting record to dynamo: " + table)
    try:
        dynamo_table = dynamodb.Table(table)
        dynamo_table.put_item(
            Item={
                'timestamp': "test"
            }
        )
    except:
        logging.error("\n[!] dynamodb table: " + table + " not found")

def get_timestamp()

def handler (event, context):

	data = event['data']

	if data['timestamp'] is None:
		data['timestamp'] = get_timestamp()

	create_record(os.environ['TABLE_NAME'], event['data'])

	print(event['data'])
