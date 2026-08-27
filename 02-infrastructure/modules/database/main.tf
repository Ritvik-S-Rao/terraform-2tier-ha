# 1. DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "devops-db-subnet-group"
  subnet_ids = var.private_data_subnet_ids

  tags = {
    Name = "devops-db-subnet-group"
  }
}

# 2. RDS MySQL Instance
resource "aws_db_instance" "main" {
  identifier           = "devops-2tier-db"
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t3.micro"
  allocated_storage    = 20
  storage_type         = "gp3"
  
  db_name              = "devopsdb"
  username             = var.db_username
  password             = var.db_password
  
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.db_security_group_id]
  
  # For a true High Availability production setup, this would be true.
  # Set to false here to keep AWS learning costs down.
  multi_az               = false
  
  # Prevents Terraform from hanging during 'terraform destroy'
  skip_final_snapshot    = true

  tags = {
    Name = "devops-2tier-db"
  }
}
