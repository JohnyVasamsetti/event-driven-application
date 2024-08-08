# S3 bucket
resource "aws_s3_bucket" "artifacts" {
  bucket = "artifacts-file-bucket"
  tags = merge(local.tags)
}



# Lambda function
resource "aws_lambda_function" "event_handler" {
  function_name = "s3-event-handler"
  role          = aws_iam_role.lambda_exec.arn
  filename      = archive_file.lambda_zip.output_path
  handler       = "main.handler"
  runtime       = "python3.8"
}

resource "archive_file" "lambda_zip" {
  output_path = "lambda_function"
  source_dir = "./function"
  type        = "zip"
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

resource "aws_iam_role_policy_attachment" "lambda_exec_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_exec.name
}