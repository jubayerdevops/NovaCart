environment        = "prod"
single_nat_gateway = false # one NAT per AZ

instance_type        = "t3.small"
asg_min_size         = 2
asg_max_size         = 6
asg_desired_capacity = 2

db_instance_class          = "db.t3.small"
db_multi_az                = true
db_deletion_protection     = true
db_backup_retention_period = 7
db_skip_final_snapshot     = false # final snapshot required

enable_bastion = false # use SSM Session Manager