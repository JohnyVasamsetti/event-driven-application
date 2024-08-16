# S3 Event Processing with Lambda, SQS, and SNS

This Terraform configuration sets up an AWS infrastructure to handle S3 events (object creation and deletion) using SQS, Lambda, and SNS. The setup is designed to send notifications via email when certain events occur in an S3 bucket and create thumbnails for `.jpg` files.

## Overview

- **S3 Bucket**: Stores files, with event notifications configured for object creation and deletion.
- **SQS Queue**: Acts as a buffer for S3 event notifications before they are processed by Lambda.
- **Lambda Function**: Processes the S3 events received via SQS. It creates thumbnails for `.jpg` files uploaded to the `images/` folder and sends email notifications to an SNS topic when any file is deleted from the S3 bucket.
- **SNS Topic**: Sends email notifications based on the processed events.

## Event Handling

- **Thumbnail Creation**: When a .jpg file is uploaded to the images/ folder in the S3 bucket, the Lambda function creates a thumbnail of the image and stores it in a thumbnails/ folder within the same bucket.
- **Email Notifications**: The Lambda function also sends an email notification via SNS whenever any file is deleted from the S3 bucket.

## Variables

- **`email_address`**: The email address to receive notifications from the SNS topic. This is passed as a variable in the Terraform configuration.

## Usage

1. **Initialize Terraform**:

   ```sh
   terraform init

   ```

2. **Apply the Configuration**:

   ```sh
   terraform apply -var="email_address=your_email@example.com"

   ```

3. **Clean Up**:
   ```sh
   terraform destroy
   ```
