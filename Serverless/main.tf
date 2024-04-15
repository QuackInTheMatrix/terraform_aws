terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.16.2"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# Storage
data "aws_s3_bucket" "website" {
  bucket = "www.ivandeveric.site"
}

data "aws_s3_object" "webapi" {
  bucket = "webapi.lambda"
  key    = "application.zip"
}

# Lambda
data "aws_iam_role" "lambda_role" {
  name = "WebAPILambdaRole"
}

resource "aws_lambda_function" "webapi" {
  function_name = "APILambda"
  role          = data.aws_iam_role.lambda_role.arn
  runtime       = "python3.11"
  s3_bucket     = data.aws_s3_object.webapi.bucket
  s3_key        = data.aws_s3_object.webapi.key
  handler       = "application.lambda_handler"
}

# API Gateway
resource "aws_api_gateway_rest_api" "webapi" {
  name = "API"
}

resource "aws_api_gateway_resource" "api" {
  rest_api_id = aws_api_gateway_rest_api.webapi.id
  parent_id   = aws_api_gateway_rest_api.webapi.root_resource_id
  path_part   = "api"
}

resource "aws_api_gateway_resource" "db" {
  rest_api_id = aws_api_gateway_rest_api.webapi.id
  parent_id   = aws_api_gateway_resource.api.id
  path_part   = "db"
}

resource "aws_api_gateway_resource" "fortunes" {
  rest_api_id = aws_api_gateway_rest_api.webapi.id
  parent_id   = aws_api_gateway_resource.db.id
  path_part   = "fortunes"
}

resource "aws_api_gateway_method" "fortune_get" {
  rest_api_id   = aws_api_gateway_rest_api.webapi.id
  resource_id   = aws_api_gateway_resource.fortunes.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "fortune_post" {
  rest_api_id   = aws_api_gateway_rest_api.webapi.id
  resource_id   = aws_api_gateway_resource.fortunes.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_get" {
  rest_api_id             = aws_api_gateway_rest_api.webapi.id
  resource_id             = aws_api_gateway_resource.fortunes.id
  http_method             = aws_api_gateway_method.fortune_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.webapi.invoke_arn
  depends_on = [
    aws_lambda_function.webapi,
    aws_api_gateway_method.fortune_get
  ]
}

resource "aws_api_gateway_integration" "lambda_post" {
  rest_api_id             = aws_api_gateway_rest_api.webapi.id
  resource_id             = aws_api_gateway_resource.fortunes.id
  http_method             = aws_api_gateway_method.fortune_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.webapi.invoke_arn
  depends_on = [
    aws_lambda_function.webapi,
    aws_api_gateway_method.fortune_post
  ]
}

# API THROTTLING
resource "aws_api_gateway_method_settings" "throttle" {
  rest_api_id = aws_api_gateway_rest_api.webapi.id
  stage_name  = aws_api_gateway_stage.development.stage_name
  method_path = "*/*"

  settings {
    throttling_burst_limit = 1
    throttling_rate_limit  = 1
  }
}

## CORS
resource "aws_api_gateway_method" "fortune_options" {
    rest_api_id   = aws_api_gateway_rest_api.webapi.id
    resource_id   = aws_api_gateway_resource.fortunes.id
    http_method   = "OPTIONS"
    authorization = "NONE"
}
### OPTIONS
resource "aws_api_gateway_method_response" "options_200" {
    rest_api_id   = aws_api_gateway_rest_api.webapi.id
    resource_id   = aws_api_gateway_resource.fortunes.id
    http_method   = aws_api_gateway_method.fortune_options.http_method
    status_code   = "200"
    response_models = {
        "application/json" = "Empty"
    }
    response_parameters = {
        "method.response.header.Access-Control-Allow-Headers" = true,
        "method.response.header.Access-Control-Allow-Methods" = true,
        "method.response.header.Access-Control-Allow-Origin" = true
    }
    depends_on = [aws_api_gateway_method.fortune_options]
}

resource "aws_api_gateway_integration" "options_integration" {
    rest_api_id   = aws_api_gateway_rest_api.webapi.id
    resource_id   = aws_api_gateway_resource.fortunes.id
    http_method   = aws_api_gateway_method.fortune_options.http_method
    type          = "MOCK"
    passthrough_behavior = "WHEN_NO_MATCH"
    request_templates = {
      "application/json" = "{ 'statusCode': 200 }"
    }
    depends_on = [aws_api_gateway_method.fortune_options]
}

resource "aws_api_gateway_integration_response" "options_integration_response" {
    rest_api_id   = aws_api_gateway_rest_api.webapi.id
    resource_id   = aws_api_gateway_resource.fortunes.id
    http_method   = aws_api_gateway_method.fortune_options.http_method
    status_code   = aws_api_gateway_method_response.options_200.status_code
    response_parameters = {
        "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
        "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,POST'",
        "method.response.header.Access-Control-Allow-Origin" = "'https://www.ivandeveric.site'"
    }
    depends_on = [aws_api_gateway_method_response.options_200]
}

### GET
resource "aws_api_gateway_method_response" "get_200" {
    rest_api_id   = aws_api_gateway_rest_api.webapi.id
    resource_id   = aws_api_gateway_resource.fortunes.id
    http_method   = aws_api_gateway_method.fortune_get.http_method
    status_code   = "200"
    response_models = {
        "application/json" = "Empty"
    }
    response_parameters = {
        "method.response.header.Access-Control-Allow-Origin" = true
    }
    depends_on = [
      aws_api_gateway_method.fortune_get,
      aws_api_gateway_integration.lambda_get
    ]
}

resource "aws_api_gateway_integration_response" "get_integration_response" {
    rest_api_id   = aws_api_gateway_rest_api.webapi.id
    resource_id   = aws_api_gateway_resource.fortunes.id
    http_method   = aws_api_gateway_method.fortune_get.http_method
    status_code   = aws_api_gateway_method_response.get_200.status_code
    response_parameters = {
        "method.response.header.Access-Control-Allow-Origin" = "'https://www.ivandeveric.site'"
    }
    depends_on = [aws_api_gateway_method_response.get_200]
}

### POST
resource "aws_api_gateway_method_response" "post_200" {
    rest_api_id   = aws_api_gateway_rest_api.webapi.id
    resource_id   = aws_api_gateway_resource.fortunes.id
    http_method   = aws_api_gateway_method.fortune_post.http_method
    status_code   = "200"
    response_models = {
        "application/json" = "Empty"
    }
    response_parameters = {
        "method.response.header.Access-Control-Allow-Origin" = true
    }
    depends_on = [
      aws_api_gateway_method.fortune_post,
      aws_api_gateway_integration.lambda_post
    ]
}

resource "aws_api_gateway_integration_response" "post_integration_response" {
    rest_api_id   = aws_api_gateway_rest_api.webapi.id
    resource_id   = aws_api_gateway_resource.fortunes.id
    http_method   = aws_api_gateway_method.fortune_post.http_method
    status_code   = aws_api_gateway_method_response.post_200.status_code
    response_parameters = {
        "method.response.header.Access-Control-Allow-Origin" = "'https://www.ivandeveric.site'"
    }
    depends_on = [aws_api_gateway_method_response.post_200]
}

## Deployment
resource "aws_api_gateway_deployment" "deployment" {
  depends_on = [
    aws_api_gateway_integration.lambda_get,
    aws_api_gateway_integration.lambda_post,
    aws_api_gateway_integration_response.post_integration_response,
    aws_api_gateway_integration_response.get_integration_response,
    aws_api_gateway_integration_response.options_integration_response,
  ]
  rest_api_id = aws_api_gateway_rest_api.webapi.id
}

resource "aws_api_gateway_stage" "development" {
  deployment_id = aws_api_gateway_deployment.deployment.id
  rest_api_id   = aws_api_gateway_rest_api.webapi.id
  stage_name    = "development"
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.webapi.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.webapi.execution_arn}/*/*"
}

# # Database
# resource "aws_dynamodb_table" "fortune-table" {
#   name           = "fortune"
#   hash_key       = "type"
#   read_capacity  = 5
#   write_capacity = 5
#   range_key      = "message"
#
#   attribute {
#     name = "type"
#     type = "S"
#   }
#
#   attribute {
#     name = "message"
#     type = "S"
#   }
# }
#

# CloudFront
locals {
  s3_origin_id = "UniqueS3OriginID"
  api_origin_id = "UniqueAPIOriginID"
}

data "aws_acm_certificate" "website" {
  domain   = "*.ivandeveric.site"
  statuses = ["ISSUED"]
}

resource "aws_cloudfront_origin_access_control" "access_s3" {
  name                              = "s3website"
  description                       = "Allow cloudfront access to s3 bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

data "aws_iam_policy_document" "s3_bucket_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${data.aws_s3_bucket.website.arn}/*"]
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.cf_www.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "cdn-oac-bucket-policy" {
  bucket = data.aws_s3_bucket.website.id
  policy = data.aws_iam_policy_document.s3_bucket_policy.json
}
## CF frontend
resource "aws_cloudfront_distribution" "cf_www" {
  enabled             = true
  aliases             = ["www.ivandeveric.site"]
  default_root_object = "index.html"
  origin {
    domain_name              = data.aws_s3_bucket.website.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.access_s3.id
    origin_id                = local.s3_origin_id
  }
  default_cache_behavior {
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["HEAD", "GET"]
    target_origin_id       = local.s3_origin_id
    viewer_protocol_policy = "allow-all"
    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
  }
  restrictions {
    geo_restriction {
      restriction_type = "none"
      locations        = []
    }
  }
  viewer_certificate {
    acm_certificate_arn      = data.aws_acm_certificate.website.arn
    minimum_protocol_version = "TLSv1.2_2021"
    ssl_support_method       = "sni-only"
  }
}
# CF BACKEND
resource "aws_cloudfront_distribution" "cf_api" {
  enabled = true
  aliases = ["api.ivandeveric.site"]
  origin {
    domain_name = "${aws_api_gateway_rest_api.webapi.id}.execute-api.us-east-1.amazonaws.com"
    origin_path = "/development"
    origin_id   = local.api_origin_id
    custom_origin_config {
      origin_protocol_policy = "https-only"
      http_port              = "80"
      https_port             = "443"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }
  default_cache_behavior {
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["HEAD", "GET"]
    target_origin_id       = local.api_origin_id
    viewer_protocol_policy = "allow-all"
    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
  }
  restrictions {
    geo_restriction {
      restriction_type = "none"
      locations        = []
    }
  }
  viewer_certificate {
    acm_certificate_arn      = data.aws_acm_certificate.website.arn
    minimum_protocol_version = "TLSv1.2_2021"
    ssl_support_method       = "sni-only"
  }
}

# Route 53
data "aws_route53_zone" "selected" {
  name = "ivandeveric.site."
}

resource "aws_route53_record" "www" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = "www.${data.aws_route53_zone.selected.name}"
  type    = "A"
  alias {
    name                   = aws_cloudfront_distribution.cf_www.domain_name
    zone_id                = aws_cloudfront_distribution.cf_www.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "api" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = "api.${data.aws_route53_zone.selected.name}"
  type    = "A"
  alias {
    name                   = aws_cloudfront_distribution.cf_api.domain_name
    zone_id                = aws_cloudfront_distribution.cf_api.hosted_zone_id
    evaluate_target_health = false
  }
}
