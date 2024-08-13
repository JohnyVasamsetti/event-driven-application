import json
import boto3

s3 = boto3.client('s3')

def handler(event, context):
    for record in event['Records']:
        print(record)
        if record['eventName'] == 'ObjectRemoved:Delete':
            print(f"Deleting Object {event['Records'][0]['s3']['object']['key']} by {record['userIdentity']['principalId']}")

        elif record['eventName'] == 'ObjectCreated:Put':
            print(f"Creating object {event['Records'][0]['s3']['object']['key']} by {record['userIdentity']['principalId']}")
            bucket  = event['Records'][0]['s3']['bucket']['name']
            key     = event['Records'][0]['s3']['object']['key']

            response = s3.get_object(Bucket=bucket, Key=key)
            image_data = response['Body'].read()

            thumb_key = key.replace("images/", "thumbnails/")

            s3.put_object(Bucket=bucket, Key=thumb_key, Body=image_data, ContentType=response['ContentType'])

    return {
        'statusCode': 200,
        'body': json.dumps('Image copied to thumbnails folder successfully!')
    }