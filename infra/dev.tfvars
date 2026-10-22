environment        = "dev"
single_nat_gateway = true

instance_type        = "t3.micro"
asg_min_size         = 1
asg_max_size         = 2
asg_desired_capacity = 1

db_instance_class          = "db.t3.micro"
db_multi_az                = false
db_deletion_protection     = false
db_backup_retention_period = 1
db_skip_final_snapshot     = true

enable_bastion = false