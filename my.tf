provider "aws"{
	region = "ap-south-1"
	profile = "myprofile"
}

resource "aws_efs_file_system" "myefs" {
	creation_token = "EFS"
	tags = {
		Name = "efs"
	}
}

resource "aws_efs_mount_target" "efs_mount" {
depends_on = [
	aws_efs_file_system.myefs,
]
	file_system_id = "${aws_efs_file_system.myefs.id}"
	subnet_id = "subnet-0378134f"
	security_groups = ["sg-0538b65402ca55807"]
}

resource "aws_instance" "MyInstance" {
depends_on = [
	aws_efs_mount_target.efs_mount
]
	ami = "ami-0447a12f28fddb066"
	instance_type = "t2.micro"
	key_name = "mykey"
	security_groups = ["sg-0538b65402ca55807"]
	subnet_id = "subnet-0378134f"

	connection {
		type = "ssh"
		user = "ec2-user"
		private_key = file("C:/Users/modif/Downloads/mykey.pem")
		host = aws_instance.MyInstance.public_ip
	}
	provisioner "remote-exec" {
		inline = [
		"sudo yum install httpd php git -y",
		"sudo systemctl restart httpd",
		"sudo systemctl enable httpd",
		"sudo yum install nfs-utils -y",
		"sudo yum install amazon-efs-utils -y",
		"sudo mount -t efs ${aws_efs_file_system.myefs.id}:/ /var/www/html",
		"sudo echo ${aws_efs_file_system.myefs.id}:/ /var/www/html efs defaults,_netdev 0 0 >> sudo /etc/fstab",
		"sudo rm -f /var/www/html/*",
		"sudo git clone https://github.com/modi2801/terra_task2.git /var/www/html/",
		]
	}
	tags = {
		Name = "MyOS1"
		}
}

resource "aws_s3_bucket" "modi2801s3bucketforimage" {
	bucket = "modi2801s3bucketforimage"
	acl = "public-read"
	force_destroy = true
	tags = {
		Name = "modi2801s3bucketforimage"
	}
}

resource "aws_s3_bucket_object" "Image" {
depends_on = [
	aws_s3_bucket.modi2801s3bucketforimage,
]
	bucket = "${aws_s3_bucket.modi2801s3bucketforimage.id}"
	key = "modi"
	source = "C:/Users/modif/OneDrive/Desktop/modi.jpg"
	acl = "public-read"
}

resource "aws_cloudfront_origin_access_identity" "OAI" {
	comment = "This is origin access identity"
}

locals {
	s3_origin_id = "aws_s3_bucket.modi2801s3bucketforimage.id"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
	enabled             = true
	is_ipv6_enabled     = true
	origin {
		domain_name = "modi2801s3bucketforimage.s3.amazonaws.com"
		origin_id = "S3-modi2801s3bucketforimage"
		s3_origin_config {
		origin_access_identity = aws_cloudfront_origin_access_identity.OAI.cloudfront_access_identity_path
		}
	}
	default_root_object = "modi"
		logging_config {
			include_cookies = false
			bucket = aws_s3_bucket.modi2801s3bucketforimage.bucket_domain_name
		}
	default_cache_behavior {
		allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
		cached_methods   = ["GET", "HEAD"]
		target_origin_id = "S3-modi2801s3bucketforimage"

		forwarded_values {
			query_string = false

			cookies {
				forward = "none"
			}
		}

		viewer_protocol_policy = "allow-all"
		min_ttl                = 0
		default_ttl            = 3600
		max_ttl                = 86400
	}
	ordered_cache_behavior {
		path_pattern = "/content/immutable/*"
		allowed_methods = ["GET" , "HEAD" , "OPTIONS"]
		cached_methods = ["GET" , "HEAD" , "OPTIONS"]
		target_origin_id = "S3-modi2801s3bucketforimage"

		forwarded_values {
		query_string = false
		headers = ["ORIGIN"]
			cookies {
				forward = "none"
			}
		}
		viewer_protocol_policy = "allow-all"
		min_ttl = 0
		default_ttl = 3600
		max_ttl = 86400
		compress = true
	}
	ordered_cache_behavior {
		path_pattern = "/content/*"
		allowed_methods = ["GET" , "HEAD" ]
		cached_methods = ["GET" , "HEAD" ]
		target_origin_id = "S3-modi2801s3bucketforimage"

		forwarded_values {
		query_string = false
		headers = ["ORIGIN"]
			cookies {
				forward = "none"
			}
		}
		viewer_protocol_policy = "allow-all"
		min_ttl = 0
		default_ttl = 3600
		max_ttl = 86400
		compress = true
	}
	
	price_class = "PriceClass_200"
	restrictions {
		geo_restriction {
			restriction_type = "none"
		}
	}
	viewer_certificate {
		cloudfront_default_certificate = true
	}
}

resource "null_resource" "MyNullResource" {
depends_on =[
	aws_cloudfront_distribution.s3_distribution
]
	connection{
		type = "ssh"
		user = "ec2-user"
		private_key = file("C:/Users/modif/Downloads/mykey.pem")
		host = aws_instance.MyInstance.public_ip
	}
	provisioner "remote-exec"{
		inline = [
		"sudo su << EOF",
		"echo \"<img src='http://${aws_cloudfront_distribution.s3_distribution.domain_name}/${aws_s3_bucket_object.Image.key}' height='400'>\" >> /var/www/html/index.html",
		"EOF",
		"sudo systemctl restart httpd",
		]
	}
}

data "aws_iam_policy_document" "MyBucketPolicy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.modi2801s3bucketforimage.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.OAI.iam_arn]
    }
  }
  statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.modi2801s3bucketforimage.arn]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.OAI.iam_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = aws_s3_bucket.modi2801s3bucketforimage.id
  policy = data.aws_iam_policy_document.MyBucketPolicy.json
}

output "IP_of_OS" {
  value = aws_instance.MyInstance.public_ip
}

output "domain_name" {
 value = aws_cloudfront_distribution.s3_distribution.domain_name
 }

resource "null_resource" "Null_Local" {
depends_on = [
	null_resource.MyNullResource
]
provisioner "local-exec" {
	command = "start chrome ${aws_instance.MyInstance.public_ip}"
	}
}
