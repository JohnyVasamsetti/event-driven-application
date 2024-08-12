# S3 bucket
resource "aws_s3_bucket" "artifacts" {
  bucket = "artifacts-file-bucket"
  tags = merge(local.tags)
}



# Lambda function
resource "null_resource" "pip_install" {
  triggers = {
    shell_hash = "${sha256(file("${path.module}/function/requirements.txt"))}"
  }

  provisioner "local-exec" {
    command = "python3 -m pip install -r ./function/requirements.txt -t ${path.module}/layer/python"
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
  role          = aws_iam_role.lambda_exec.arn
  filename      = data.archive_file.code_archive.output_path
  source_code_hash = data.archive_file.code_archive.output_base64sha256
  handler       = "main.handler"
  runtime       = "python3.10"
  layers        = [aws_lambda_layer_version.layer.arn]
}


# bucket notifications
resource "aws_s3_bucket_notification" "s3_event_notifications" {
  bucket = aws_s3_bucket.artifacts.id
  lambda_function {
    lambda_function_arn = aws_lambda_function.event_handler.arn
    events = ["s3:ObjectCreated:*"]
    filter_prefix = "images/"
    filter_suffix = ".jpg"
  }
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
  path        = "/"
  description = "Permissions for lambda function to execute code"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "S3ObjectGetPermissions"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Effect   = "Allow"
        Resource = "${aws_s3_bucket.artifacts.arn}/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_exec_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_exec.name
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