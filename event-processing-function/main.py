import boto3
import os
import json

def handler(messages, context):
    sqs = boto3.client('sqs')
    s3 = boto3.client('s3')
    sns = boto3.client('sns')

    sns_topic_arn = os.environ.get('sns_topic_arn')
    sqs_pool_url = os.environ.get('sqs_pool_url')

    for message in messages['Records']:
        events = eval(message['body'])
        if events.get('Event') == 's3:TestEvent' :
            print('It was an Test Event')
        else:
            for event in events['Records']:
                print(event['eventName'])
                bucket  = event['s3']['bucket']['name']
                object     = event['s3']['object']['key']
                user    = event['userIdentity']['principalId']
                timestamp = event['eventTime']
                
                if event['eventName'] == 'ObjectCreated:Put':
                    print(f"Creating object {object} by {user}")
        
                    response = s3.get_object(Bucket=bucket, Key=object)
                    image_data = response['Body'].read()
        
                    thumb_object = object.replace("images/", "thumbnails/")
        
                    s3.put_object(Bucket=bucket, Key=thumb_object, Body=image_data, ContentType=response['ContentType'])
    
                elif event['eventName'] == 'ObjectRemoved:DeleteMarkerCreated':
                    print(f"Deleting Object {object} by {user}")
                    message_to_sns = {
                        'bucket' : bucket,
                        'object' : object,
                        'user' : user,
                        'timestamp' : timestamp
                    }
                    sns.publish(TopicArn=sns_topic_arn,Message=json.dumps(message_to_sns))
        sqs.delete_message(
            QueueUrl = sqs_pool_url,
            ReceiptHandle = message['receiptHandle']
        )
        print(f"Deleted message {message['messageId']} from sqs successfully!")

    return {
        'statusCode': 200,
        'body': json.dumps(f"Messages processed successfully!")
    }