/*Tell the terraform that i want to create infrastructure on aws cloud as terraform has a support for almost all the cloud services provider 
*/
provider "aws"{
   region = "ap-south-1"
   profile = "gaurav02"
}
//creating a instance 
resource"aws_instance" "web"{
 ami ="ami-0447a12f28fddb066"
 instance_type = "t2.micro"
 key_name = "mykey1234"
 security_groups=["launch-wizard-5"]

   connection{
      type = "ssh"
      user = "ec2-user"
      private_key = file("C:/Users/gaura/Downloads/mykey1234.pem")
      host = aws_instance.web.public_ip
     }
//performing various commands on remote machine 
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
//creating the EBS volume
resource "aws_ebs_volume" "ebs1"{
  availability_zone = aws_instance.web.availability_zone
  size = 1
  tags = {
   name = "gaebs"
     }
}
//attaching the Ebs volume to the instance
resource "aws_volume_attachment" "ebs_att"{
  device_name = "/dev/sdh"
  volume_id = "${aws_ebs_volume.ebs1.id}"
  instance_id = "${aws_instance.web.id}"
  force_detach =true
}

output "os_ip"{
   value = aws_instance.web.public_ip
}
//null-resource for executing command on localmachine
resource "null_resource" "null-local-1"{
      provisioner "local-exec"{
          command="echo ${aws_instance.web.public_ip} > publicip.txt"
           }
 }
// for putting our git code on to the remote machine 
resource "null_resource" "null-local-2"{
 depends_on =[
       aws_volume_attachment.ebs_att,
            ]
  connection{
     type ="ssh"
     user ="ec2-user"
     private_key = file("C:/Users/gaura/Downloads/mykey1234.pem")
     host =aws_instance.web.public_ip
    }
  provisioner "remote-exec"{
     inline = [
         "sudo mkfs.ext4 /dev/xvdh",
         "sudo mount /dev/xvdh /var/www/html",
         "sudo rm -rf /var/www/html/*",
         " sudo git clone https://github.com/gauravlangar/JavaScriptProject.git /var/www/html/"
         ]
       }
    }
//for launching our web application
resource "null_resource" "null-local-3"{
depends_on = [
      null_resource.null-local-2,
           ]
 provisioner "local-exec"{
      command ="start chrome  ${aws_instance.web.public_ip}"
         }
}