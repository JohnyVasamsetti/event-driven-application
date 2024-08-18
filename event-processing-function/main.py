import boto3
import os
import json
import imageio
import numpy as np

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
                key     = event['s3']['object']['key']
                user    = event['userIdentity']['principalId']
                timestamp = event['eventTime']
                
                if event['eventName'] == 'ObjectCreated:Put':
                    print(f"Creating object {key} by {user}")
        
                    response = s3.get_object(Bucket=bucket, Key=key)
                    image = imageio.imread(io.BytesIO(response['Body'].read()))

                    # Resize image to thumbnail size
                    thumbnail_size = (128, 128)
                    image_resized = np.array(Image.fromarray(image).resize(thumbnail_size))

                    thumb_io = io.BytesIO()
                    imageio.imwrite(thumb_io, image_resized, format='jpeg')
                    thumb_io.seek(0)

                    thumb_key = key.replace("images/", "thumbnails/")
                    s3.put_object(Bucket=bucket, Key=thumb_key, Body=thumb_io, ContentType='image/jpeg')
    
                elif event['eventName'] == 'ObjectRemoved:DeleteMarkerCreated':
                    print(f"Deleting Object {key} by {user}")
                    message_to_sns = {
                        'bucket' : bucket,
                        'key' : key,
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