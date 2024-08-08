def handler(event, context):
    print("Hello from handler function !")
    return {
        'statusCode': 200,
        'body': json.dumps('Notification sent successfully to the domain team')
    }