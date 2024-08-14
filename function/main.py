import json
import boto3
import os

s3 = boto3.client('s3')
sns = boto3.client('sns')

def handler(event, context):
    sns_topic_arn = os.environ.get('sns_topic_arn')
    print(sns_topic_arn)
    for record in event['Records']:
        bucket  = record['s3']['bucket']['name']
        object     = record['s3']['object']['key']
        user    = record['userIdentity']['principalId']

        if record['eventName'] == 'ObjectRemoved:Delete':
            print(f"Deleting Object {object} by {user}")
            sns.publish(TopicArn=sns_topic_arn,Message='Sending first message')
            print("Message has been added to sns")

        elif record['eventName'] == 'ObjectCreated:Put':
            print(f"Creating object {object} by {user}")
            

            response = s3.get_object(Bucket=bucket, Key=object)
            image_data = response['Body'].read()

            thumb_object = object.replace("images/", "thumbnails/")

            s3.put_object(Bucket=bucket, Key=thumb_object, Body=image_data, ContentType=response['ContentType'])

    return {
        'statusCode': 200,
        'body': json.dumps('Image copied to thumbnails folder successfully!')
    }