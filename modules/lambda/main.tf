resource "null_resource" "this" {
  triggers = {
    shell_hash = "${sha256(file("${path.module}/event_handle_function/requirements.txt"))}"
  }

  provisioner "local-exec" {
    command = "python3 -m pip install -r ./event_handle_function/requirements.txt -t ${path.module}/layer/python"
  }
}

resource "aws_lambda_layer_version" "this" {
  layer_name = "python-dependencies"
  filename = data.archive_file.dependency_archive.output_path
  source_code_hash = data.archive_file.dependency_archive.output_base64sha256
  compatible_runtimes = ["python3.9", "python3.10"]
}

resource "aws_lambda_function" "this" {
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