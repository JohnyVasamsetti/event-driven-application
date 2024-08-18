resource "aws_s3_bucket" "artifacts" {
  bucket = "artifacts-file-bucket"
}

resource "aws_sqs_queue" "event_pool" {
  name = "s3-event-pool"
}

resource "aws_s3_bucket_notification" "s3_object_delete_and_create_event_notifications" {
  bucket = aws_s3_bucket.artifacts.id
  queue {
    queue_arn = aws_sqs_queue.event_pool.arn
    events = ["s3:ObjectCreated:*"]
    filter_prefix = "images/"
    filter_suffix = ".jpg"
  }
  
  queue {
    queue_arn = aws_sqs_queue.event_pool.arn
    events = ["s3:ObjectRemoved:*"]
  }
}

resource "aws_sqs_queue_policy" "sqs_access_policy" {
  policy    = templatefile("./policies/sqs-access-policy.json",{
    sqs_pool_arn: aws_sqs_queue.event_pool.arn,
    s3_bucket_arn: aws_s3_bucket.artifacts.arn
  })
  queue_url = aws_sqs_queue.event_pool.id
}

resource "aws_lambda_function" "event_processor_function" {
  function_name = "s3-event-processor"
  filename      = data.archive_file.event_processing_code.output_path
  source_code_hash = data.archive_file.event_processing_code.output_base64sha256
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "main.handler"
  runtime       = "python3.10"

  environment {
    variables = {
      sns_topic_arn = aws_sns_topic.notification_topic.arn,
      sqs_pool_url = aws_sqs_queue.event_pool.id
    }
  }
}

resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_exec_policy" {
  name        = "lambda-exec-policy"
  description = "Permissions for lambda function to execute code"
  policy = templatefile("./policies/lambda-exec-policy.json",{
    s3_bucket_arn : aws_s3_bucket.artifacts.arn,
    account_id: data.aws_caller_identity.current.account_id,
    function_name: aws_lambda_function.event_processor_function.function_name,
    sns_topic_arn: aws_sns_topic.notification_topic.arn,
    sqs_pool_arn: aws_sqs_queue.event_pool.arn
  })
}

resource "aws_iam_role_policy_attachment" "lambda_exec_role_policy_attachement" {
  policy_arn = aws_iam_policy.lambda_exec_policy.arn
  role       = aws_iam_role.lambda_exec_role.name
}

resource "aws_lambda_event_source_mapping" "events_to_lambda_mapping" {
  event_source_arn = aws_sqs_queue.event_pool.arn
  function_name = aws_lambda_function.event_processor_function.arn
  batch_size = 1
}

resource "aws_sns_topic" "notification_topic" {
  name = "s3-event-notifications"
}

resource "aws_sns_topic_subscription" "mail_subscription_to_sns" {
  topic_arn = aws_sns_topic.notification_topic.arn
  protocol = "email"
  endpoint = var.email_address
}