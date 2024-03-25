provider "aws" {
  region = "us-east-1"
}

# Lambda execution role and policy
resource "aws_iam_role" "scaas_manager_role" {
  name = "scaas_manager_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "scaas_manager_policy" {
  name        = "scaas_manager_policy"
  description = "Policy to allow Lambda function to interact with EC2"
  
  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "ec2:DescribeImages",
          "ec2:RunInstances"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "scaas_manager_policy_attachment" {
  role       = aws_iam_role.scaas_manager_role.name
  policy_arn = aws_iam_policy.scaas_manager_policy.arn
}

# IAM policy for API Gateway to invoke Lambda function
resource "aws_iam_policy" "scaas_gateway_policy" {
  name        = "scaas_gateway_policy"
  description = "Policy to allow API Gateway to invoke Lambda function"
  
  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = "lambda:InvokeFunction",
        Resource = "${aws_lambda_function.scaas_manager.arn}"
      }
    ]
  })
}

resource "aws_iam_role" "scaas_gateway_role" {
  name = "scaas_gateway_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "apigateway.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "scaas_gateway_policy_attachment" {
  role       = aws_iam_role.scaas_gateway_role.name
  policy_arn = aws_iam_policy.scaas_gateway_policy.arn
}

# Assume that the Lambda function code is in the 'lambda' directory
data "archive_file" "scaas_manager_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda"
  output_path = "${path.module}/lambda_function.zip"
}

resource "aws_lambda_function" "scaas_manager" {
  function_name = "scaas_manager"
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.8"
  role          = aws_iam_role.scaas_manager_role.arn
  filename      = data.archive_file.scaas_manager_lambda.output_path
  source_code_hash = data.archive_file.scaas_manager_lambda.output_base64sha256

  timeout     = 10
}

# API Gateway setup
resource "aws_api_gateway_rest_api" "scaas_gateway" {
  name        = "scaas_gateway"
  description = "SCaaS API Gateway"
}

resource "aws_api_gateway_resource" "scan_resource" {
  rest_api_id = aws_api_gateway_rest_api.scaas_gateway.id
  parent_id   = aws_api_gateway_rest_api.scaas_gateway.root_resource_id
  path_part   = "scan"
}

resource "aws_api_gateway_method" "scan_post" {
  rest_api_id   = aws_api_gateway_rest_api.scaas_gateway.id
  resource_id   = aws_api_gateway_resource.scan_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.scaas_gateway.id
  resource_id             = aws_api_gateway_resource.scan_resource.id
  http_method             = aws_api_gateway_method.scan_post.http_method
  type                    = "AWS"
  integration_http_method = "POST"
  uri                     = aws_lambda_function.scaas_manager.invoke_arn
  credentials             = aws_iam_role.scaas_gateway_role.arn
}

resource "aws_api_gateway_method_response" "response_200" {
  rest_api_id = aws_api_gateway_rest_api.scaas_gateway.id
  resource_id = aws_api_gateway_resource.scan_resource.id
  http_method = aws_api_gateway_method.scan_post.http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "integration_response_200" {
  rest_api_id = aws_api_gateway_rest_api.scaas_gateway.id
  resource_id = aws_api_gateway_resource.scan_resource.id
  http_method = aws_api_gateway_integration.lambda_integration.http_method
  status_code = aws_api_gateway_method_response.response_200.status_code

  response_templates = {
    "application/json" = ""
  }

  selection_pattern = "" # Match all successful responses
}

resource "aws_api_gateway_deployment" "scaas_gateway_deployment" {
  depends_on = [
    aws_api_gateway_integration.lambda_integration
  ]

  rest_api_id = aws_api_gateway_rest_api.scaas_gateway.id

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "scaas_gateway_stage" {
  deployment_id = aws_api_gateway_deployment.scaas_gateway_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.scaas_gateway.id
  stage_name    = "v1"
}
