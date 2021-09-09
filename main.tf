terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }

  required_version = ">= 0.14.9"
}

provider "aws" {
  profile = "default"
  region  = "eu-west-2"
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "src"
  output_path = "strip_metadata_lambda.zip"
}

resource "aws_s3_bucket" "gen_england_bucket_a" {
  bucket        = "gen-england-bucket-a"
  force_destroy = true
}

resource "aws_s3_bucket" "gen_england_bucket_b" {
  bucket        = "gen-england-bucket-b"
  force_destroy = true
}

resource "aws_lambda_permission" "allow_bucket_to_execute_lambda" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.strip_metadata.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.gen_england_bucket_a.arn
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.gen_england_bucket_a.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.strip_metadata.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".jpg"
  }

  depends_on = [aws_lambda_permission.allow_bucket_to_execute_lambda]
}

resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "s3_lambda_policy" {
  name   = "s3-lambda-genom-policy"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject"
      ],
      "Resource": ["arn:aws:s3:::gen-england-bucket-a/*"]
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject"
      ],
      "Resource": ["arn:aws:s3:::gen-england-bucket-b/*"]
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "s3_lambda_policy_attachment" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.s3_lambda_policy.arn
}

resource "aws_iam_role_policy_attachment" "terraform_lambda_policy" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_layer_version" "lambda_layer" {
  filename   = "src/pil-layer.zip"
  layer_name = "pil-layer"

  compatible_runtimes = ["python3.7"]
}

resource "aws_lambda_function" "strip_metadata" {
  function_name    = "strip_metadata"
  role             = aws_iam_role.iam_for_lambda.arn
  handler          = "strip_metadata.strip"
  runtime          = "python3.7"
  description      = "Strips exif metadata from jpgs"
  filename         = "strip_metadata_lambda.zip"
  timeout          = 15
  memory_size      = 2048
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  layers = [
    aws_lambda_layer_version.lambda_layer.arn,
  ]

  environment {
    variables = {
      BUCKET_B = aws_s3_bucket.gen_england_bucket_b.bucket
    }
  }
}

resource "aws_iam_user" "a" {
  name = "user_a"
}

resource "aws_iam_user_policy" "rw_bucket_a" {
  name = "rw_bucket_a"
  user = aws_iam_user.a.name

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject"
      ],
      "Resource": ["arn:aws:s3:::gen-england-bucket-a/*"]
    }
  ]
}
EOF
}

resource "aws_iam_user" "b" {
  name = "user_b"
}

resource "aws_iam_user_policy" "rw_bucket_b" {
  name = "rw_bucket_b"
  user = aws_iam_user.b.name

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject"
      ],
      "Resource": ["arn:aws:s3:::gen-england-bucket-b/*"]
    }
  ]
}
EOF
}
