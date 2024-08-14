# S3 bucket
resource "aws_s3_bucket" "artifacts" {
  bucket = "artifacts-file-bucket"
  tags = merge(local.tags)
}

# Lambda function
resource "null_resource" "pip_install" {
  triggers = {
    shell_hash = "${sha256(file("${path.module}/event_handle_function/requirements.txt"))}"
  }

  provisioner "local-exec" {
    command = "python3 -m pip install -r ./event_handle_function/requirements.txt -t ${path.module}/layer/python"
  }
}

resource "aws_lambda_layer_version" "layer" {
  layer_name = "python-dependencies"
  filename = data.archive_file.dependency_archive.output_path
  source_code_hash = data.archive_file.dependency_archive.output_base64sha256
  compatible_runtimes = ["python3.9", "python3.10"]
}

resource "aws_lambda_function" "event_handler" {
  function_name = "s3-event-handler"
  filename      = data.archive_file.code_archive.output_path
  source_code_hash = data.archive_file.code_archive.output_base64sha256
  role          = aws_iam_role.lambda_exec.arn
  handler       = "main.handler"
  runtime       = "python3.10"
  layers        = [aws_lambda_layer_version.layer.arn]

  environment {
    variables = {
      sns_topic_arn = aws_sns_topic.notification_topic.arn,
      sqs_pool_url = aws_sqs_queue.event_queue.id
    }
  }
}


# bucket notifications to lambda
resource "aws_s3_bucket_notification" "s3_delete_and_create_event_notifications" {
  bucket = aws_s3_bucket.artifacts.id
  lambda_function {
    lambda_function_arn = aws_lambda_function.event_handler.arn
    events = ["s3:ObjectCreated:*"]
    filter_suffix = ".jpg"
  }
}

# sqs
resource "aws_sqs_queue" "event_queue" {
  name = "s3-event-pool"
}

resource "aws_sqs_queue_policy" "sqs_access_policy" {
  policy    = templatefile("./sqs-access-policy.json",{
    sns_topic_arn: aws_sns_topic.notification_topic.arn,
    sqs_pool_arn: aws_sqs_queue.event_queue.arn
  })
  queue_url = aws_sqs_queue.event_queue.id
}

resource "aws_lambda_event_source_mapping" "sqs_to_lambda_mapping" {
  event_source_arn = aws_sqs_queue.event_queue.arn
  function_name = aws_lambda_function.event_handler.arn
  enabled = true
  batch_size = 1
}

# sns topic
resource "aws_sns_topic" "notification_topic" {
  name = "s3-event-notifications"
}

resource "aws_sns_topic_subscription" "sqs_subscribes_sns" {
  topic_arn = aws_sns_topic.notification_topic.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.event_queue.arn
}


# Roles & Policies
resource "aws_iam_role" "lambda_exec" {
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
  policy = templatefile("./lambda-exec-policy.json",{
    s3_bucket_arn : aws_s3_bucket.artifacts.arn,
    account_id: data.aws_caller_identity.current.account_id,
    function_name: aws_lambda_function.event_handler.function_name,
    sns_topic_arn: aws_sns_topic.notification_topic.arn,
    sqs_pool_arn: aws_sqs_queue.event_queue.arn
  })
}

resource "aws_iam_role_policy_attachment" "lambda_exec_policy-2" {
  policy_arn = aws_iam_policy.lambda_exec_policy.arn
  role       = aws_iam_role.lambda_exec.name
}

resource "aws_lambda_permission" "allow_s3_to_call_lambda" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.event_handler.function_name
  principal     = "s3.amazonaws.com"
  source_arn = aws_s3_bucket.artifacts.arn
}