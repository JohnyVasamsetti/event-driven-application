import boto3
import os
import json



def handler(event, context):
    s3 = boto3.client('s3')
    sns = boto3.client('sns')
    sqs = boto3.client('sqs')

    sns_topic_arn = os.environ.get('sns_topic_arn')
    sqs_pool_url = os.environ.get('sqs_pool_url')

    for record in event['Records']:
        bucket  = record['s3']['bucket']['name']
        object     = record['s3']['object']['key']
        user    = record['userIdentity']['principalId']

        if record['eventName'] == 'ObjectCreated:Put':
            print(f"Creating object {object} by {user}")

            sqs.send_message(
                QueueUrl = sqs_pool_url,
                MessageBody = json.dumps({
                    'bucket': bucket,
                    'object': object
                })
            )

            # response = s3.get_object(Bucket=bucket, Key=object)
            # image_data = response['Body'].read()

            # thumb_object = object.replace("images/", "thumbnails/")

            # s3.put_object(Bucket=bucket, Key=thumb_object, Body=image_data, ContentType=response['ContentType'])

        elif record['eventName'] == 'ObjectRemoved:Delete':
            print(f"Deleting Object {object} by {user}")
            sns.publish(TopicArn=sns_topic_arn,Message='Sending first message')
            print("Message has been added to sns")

    return {
        'statusCode': 200,
        'body': json.dumps('Image copied to thumbnails folder successfully!')
    }