provider "aws"{
   region = "ap-south-1"
   profile = "gaurav02"
}

resource "aws_security_group" "http" {
  name        = "http"
ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
   from_port   = 0
   to_port     = 0
   protocol    = "-1"
   cidr_blocks = ["0.0.0.0/0"]
 }
tags = {
   Name = "http"
 }
}

resource "aws_instance" "webser1" {
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name 	=  "mykey1234"
  security_groups = [ "http" ]

   connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/gaura/Downloads/mykey1234.pem")
    host     = aws_instance.webser1.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }

  tags = {
    Name = "webserver"
  }
}

resource "aws_ebs_volume" "EBS" {
  availability_zone = aws_instance.webser1.availability_zone
  size              = 1
  tags = {
    Name = "extradisk"
  }
}



resource "aws_volume_attachment" "ebs_attach" {
  device_name = "/dev/sdd"
  volume_id   = "${aws_ebs_volume.EBS.id}"
  instance_id = "${aws_instance.webser1.id}"
  force_detach = true
}



output "instance_ip" {
	value = aws_instance.webser1.public_ip
}

resource "null_resource" "nulllocal"  {
  depends_on = [
  aws_instance.webser1,
  ]
	provisioner "local-exec" {
	    command = "echo  ${aws_instance.webser1.public_ip} > publicip.txt"
  	}
}

resource "null_resource" "nullremote"  {
 depends_on = [
    aws_volume_attachment.ebs_attach,
  ]

  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/gaura/Downloads/mykey1234.pem")
    host     = aws_instance.webser1.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdh",
      "sudo mount  /dev/xvdh  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "git clone https://github.com/gauravlangar/aws_task.git /var/www/html/"
    ]
  }
}

output "ebs_name" {
	value = aws_ebs_volume.EBS.id
}

resource "aws_s3_bucket" "mybuck007" {
  bucket = "mybuck007"
  acl    = "public-read"
  tags = {
      Name = "mybuck007"
      Environment = "Dev"
  }
}

resource "aws_s3_bucket_object" "bucket_obj" {
  bucket = "${aws_s3_bucket.mybuck007.id}"
  key    = "image1.jpg"
  source = "C:/Users/gaura/Downloads/image1.jpg"
  acl	 = "public-read"
}

resource "aws_cloudfront_distribution" "cfd" {
  origin {
    domain_name = "${aws_s3_bucket.mybuck007.bucket_regional_domain_name}"
    origin_id   = "${aws_s3_bucket.mybuck007.id}"
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "S3 Web Distribution"

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${aws_s3_bucket.mybuck007.id}"

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

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["IN"]
    }
  }

  tags = {
    Name        = "Web-CF-Distribution"
    Environment = "Production"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  depends_on = [
    aws_s3_bucket.mybuck007
  ]
}
resource "null_resource" "null-local-3"{
depends_on = [
      aws_cloudfront_distribution.cfd,null_resource.nullremote
           ]
 provisioner "local-exec"{
      command ="start chrome  ${aws_instance.webser1.public_ip}"
         }
}
