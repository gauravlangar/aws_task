provider "aws"{
    region = "ap-south-1"
 }

resource "tls_private_key" "this"{
 algorithm = "RSA"
 }

resource "local_file" "private_key"{
  content  =  tls_private_key.this.private_key_pem
  filename =  "mykey1234.pem"
 }
resource "aws_key_pair" "mykey1234"{
 key_name   = "mykey_new"
 public_key = tls_private_key.this.public_key_openssh
}
resource "aws_security_group" "security_allow" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"


  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH from VPC"
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
    Name = "security_allow"
  }
}
resource"aws_instance" "web"{
 ami ="ami-0447a12f28fddb066"
 instance_type = "t2.micro"
 key_name = "mykey1234"
 security_groups=["security_allow"]

   connection{
      type = "ssh"
      user = "ec2-user"
      private_key = file("C:/Users/gaura/Downloads/mykey1234(1).pem")
      host = aws_instance.web.public_ip
     }

   provisioner"remote-exec"{
     inline = [
          "sudo yum install httpd php git -y",
          "sudo systemctl restart httpd",
          "sudo systemctl enable httpd",
           ]
          }
tags={
 Name="task01"
 }
}
resource "aws_ebs_volume" "ebs1"{
  availability_zone = aws_instance.web.availability_zone
  size = 1
  tags = {
   name = "gaebs"
     }
}
resource "aws_volume_attachment" "ebs_att"{
  device_name = "/dev/sdh"
  volume_id = "${aws_ebs_volume.ebs1.id}"
  instance_id = "${aws_instance.web.id}"
  force_detach =true
}

resource "null_resource" "nullremote"  {


    depends_on = [
       aws_volume_attachment.ebs_att,
   ]


    connection {
        type     = "ssh"
        user     = "ec2-user"
        private_key = tls_private_key.this.private_key_pem
        port    = 22
        host     = aws_instance.web.public_ip
   }


  provisioner "remote-exec" {
      inline = [
          "sudo mkfs.ext4  /dev/xvdf",
          "sudo mount  /dev/xvdf  /var/www/html",
          "sudo rm -rf /var/www/html/*",
          "sudo git clone https://github.com/gauravlangar/JavaScriptProject.git /var/www/html/"
     ]
   }
 }


resource "aws_s3_bucket" "task01-s3_bucket" {
  bucket = "task01-s3_bucket"
  acl    = "public-read"

  tags = {
    Name        = "bucket-01"
    Environment = "Dev"
  }
}

resource "aws_s3_bucket_object" "upload" {
  bucket = "${aws_s3_bucket.task01-s3_bucket}"
  key    = "image1.jpg"
  source = "C:/Users/gaura/Downloads/image1.gif"
  acl ="public-read"
}

locals {
   s3_origin_id = "S3-${aws_s3_bucket.task01-s3_bucket.bucket}"
 }
resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = "${aws_s3_bucket.task01-s3_bucket.bucket_regional_domain_name}"
   origin_id   = local.s3_origin_id
  }


enabled     = true

 default_cache_behavior {
     allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${local.s3_origin_id}"


     forwarded_values {
       query_string = false


       cookies {
         forward = "none"
       }
     }


     viewer_protocol_policy = "allow-all"

   }



 restrictions {
     geo_restriction {
       restriction_type = "none"

     }
    }

   viewer_certificate {
     cloudfront_default_certificate = true
  }
  connection {
        type    = "ssh"
        user    = "ec2-user"
        host    = aws_instance.web.public_ip
        port    = 22
        private_key = tls_private_key.this.private_key_pem
    }
provisioner "remote-exec" {
        inline  = [
            "sudo su << EOF",
            "echo \"<img src='http://${self.domain_name}/${aws_s3_bucket_object.upload.key}'>\" >> /var/www/html/index.html",
            "EOF"
        ]
   }
  }
resource "null_resource" "null-local-3"{
depends_on = [
      null_resource.nullremote,
           ]
 provisioner "local-exec"{
      command ="start chrome  ${aws_instance.web.public_ip}"
         }
}
