data "archive_file" "event_processing_code" {
    type = "zip"
    source_dir = "${path.module}/event-processing-function"
    output_path = "${path.module}/event-processing-function.zip"
}

data "aws_caller_identity" "current" {}
