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

# module "dir" {
#   source  = "hashicorp/dir/template"
#   version = "1.0.2"
#   base_dir = "website"
# }
#
# Network
data "aws_vpc" "default_vpc" {
  default = true
}

data "aws_subnets" "default_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default_vpc.id]
  }
}

# #Storage
# resource "aws_s3_bucket" "webapi" {
#   bucket = "webapi.storage"
# }
#
# resource "aws_s3_object" "object" {
#   bucket = aws_s3_bucket.webapi.id
#   key    = "Archive.zip"
#   source = "Archive.zip"
#   etag   = filemd5("Archive.zip")
# }
#
# resource "aws_s3_bucket" "website" {
#   bucket = "fortune.website.storage"
# }
#
# resource "aws_s3_object" "website_files" {
#   for_each = module.dir.files
#
#   bucket = aws_s3_bucket.website.id
#   key    = each.key
#   content_type = each.value.content_type
#   source  = each.value.source_path
#   etag = each.value.digests.md5
# }
#
data "aws_s3_object" "webapi" {
  bucket = "webapi.beanstalk"
  key    = "Archive.zip"
}

data "aws_s3_bucket" "website" {
  bucket = "www.ivandeveric.site"
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
# Beanstalk
resource "aws_elastic_beanstalk_application" "webapi" {
  name        = "webapi"
  description = "webapi using flask"
}

resource "aws_elastic_beanstalk_application_version" "development" {
  name        = "webapi-dev-version"
  application = aws_elastic_beanstalk_application.webapi.name
  description = "development version of webapi application"
  bucket      = data.aws_s3_object.webapi.bucket
  key         = data.aws_s3_object.webapi.key
}

resource "aws_elastic_beanstalk_environment" "development" {
  name                = "webapi-dev"
  application         = aws_elastic_beanstalk_application.webapi.name
  solution_stack_name = "64bit Amazon Linux 2023 v4.0.3 running Python 3.11"
  tier                = "WebServer"
  version_label       = aws_elastic_beanstalk_application_version.development.name

  setting {
    namespace = "aws:ec2:vpc"
    name      = "VPCId"
    value     = data.aws_vpc.default_vpc.id
  }
  setting {
    namespace = "aws:ec2:vpc"
    name      = "Subnets"
    value     = join(",", data.aws_subnets.default_subnets.ids)
  }
  setting {
    namespace = "aws:ec2:vpc"
    name      = "AssociatePublicIpAddress"
    value     = "True"
  }
  setting {
    namespace = "aws:ec2:vpc"
    name      = "ELBScheme"
    value     = "internet facing"
  }
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = "EC2AccessDynamoDB"
  }
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "SecurityGroups"
    value     = "sg-042cd2ad2c4e423fd"
  }
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "InstanceType"
    value     = "t2.micro"
  }
  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MinSize"
    value     = 2
  }
  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MaxSize"
    value     = 2
  }
  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "ServiceRole"
    value     = "AWSServiceRoleForElasticBeanstalk"
  }
  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "LoadBalancerType"
    value     = "application"
  }
  setting {
    namespace = "aws:elasticbeanstalk:environment:process:default"
    name      = "MatcherHTTPCode"
    value     = "302"
  }
  setting {
    namespace = "aws:elasticbeanstalk:environment:process:default"
    name      = "Port"
    value     = 80
  }
  setting {
    namespace = "aws:elasticbeanstalk:healthreporting:system"
    name      = "SystemType"
    value     = "enhanced"
  }
}

# CloudFront
locals {
  s3_origin_id = "UniqueS3OriginID"
  bs_origin_id = "UniquedBSOriginID"
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
    domain_name = aws_elastic_beanstalk_environment.development.endpoint_url
    origin_id   = local.bs_origin_id
    custom_origin_config {
      origin_protocol_policy = "http-only"
      http_port              = "80"
      https_port             = "443"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }
  default_cache_behavior {
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["HEAD", "GET"]
    target_origin_id       = local.bs_origin_id
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
