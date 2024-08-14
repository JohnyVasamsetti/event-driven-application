data "archive_file" "code_archive" {
    type = "zip"
    source_dir = "${path.module}/event_handle_function"
    output_path = "${path.module}/event_handle_function.zip"
    
}

data "archive_file" "dependency_archive" {
    type = "zip"
    source_dir = "${path.module}/layer"
    output_path = "${path.module}/layer.zip"
    depends_on  = [null_resource.pip_install]
}

data "aws_caller_identity" "current" {}
