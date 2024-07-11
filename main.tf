data "terraform_remote_state" "alks" {
  backend = "s3"

  config = {
    region = "us-east-1"
    bucket = "${var.alks_account}-terraform-state"
    key    = var.remote_state_key_iam
  }
}

data "terraform_remote_state" "managed_vpc" {
  backend = "s3"

  config = {
    region = "us-east-1"
    bucket = "${var.alks_account}-terraform-state"
    key    = var.remote_state_key_managed_network
  }
}

locals {
  additional_private_subnet_ids = data.terraform_remote_state.managed_vpc.outputs.default_private_subnet_ids[var.region]
  private_subnet_ids            = data.terraform_remote_state.managed_vpc.outputs.default_private_subnet_ids[var.region]
  public_subnet_ids             = data.terraform_remote_state.managed_vpc.outputs.all_public_subnet_ids[var.region]
  all_public_subnet_ids_ordered = data.terraform_remote_state.managed_vpc.outputs.all_public_subnet_ids_ordered[var.region] // ordered by name (external-001,002, etc)
  private_subnet_azs            = data.terraform_remote_state.managed_vpc.outputs.private_subnet_azs[var.region]
  vpc_id                        = data.terraform_remote_state.managed_vpc.outputs.vpc_id[var.region]

  graviton_amis = tomap({ "us-east-1" : "ami-0c3dda3deab25a563", "us-west-1" : "ami-00872c48515f06ba0" })

  // Temporary until swap to new AMI
  amazon_linux2_x86_ami_ids = tomap({ "us-east-1" : "ami-03e0b06f01d45a4eb", "us-west-1" : "ami-052f64d0cd359fe1f" })
  new_graviton_amis = tomap({ "us-east-1" : "ami-0c0280b033aeb3097", "us-west-1": "ami-0cb4f1560d29b2155" })

  configcache_graviton_amis = tomap({ "us-east-1" : "ami-0f2a9086c2e364a65", "us-west-1": "ami-04d628de228425cfd" })

  // amzn2-ami-kernel-5.10-hvm-2.0.20240529.0-arm64-gp2
  ads_ami = tomap({"us-east-1": "ami-0f2a9086c2e364a65", "us-west-1": "ami-04d628de228425cfd"})
  // amzn2-ami-kernel-5.10-hvm-2.0.20240529.0-arm64-gp2
  pix_ami = tomap({"us-east-1": "ami-0f2a9086c2e364a65", "us-west-1": "ami-04d628de228425cfd"})
  // amzn2-ami-kernel-5.10-hvm-2.0.20240529.0-arm64-gp2
  bidder_ami = tomap({"us-east-1": "ami-0f2a9086c2e364a65", "us-west-1": "ami-04d628de228425cfd"})

  rds_snapshot_replication_targets = tomap({
    "us-west-1" : [
      var.budget_rds_master,
      var.impression_single_instance_rds_master
    ],
    "us-east-1" : []
  })
}

data "aws_ami" "standard_rtb_app_ami" {
  most_recent = true
  owners      = ["self", "amazon", "715852559442"]

  filter {
    name   = "name"
    values = [var.ads_ami_name]
  }
}

// TODO restore me
/*data "aws_ami" "graviton_ami" {
  most_recent = true
  owners      = ["self", "amazon", "715852559442"]

  filter {
    name   = "name"
    values = [var.bidder_ami_name]
  }
}*/


// Disabled until newer AMI is setup.
// This is used by ICMUpdater, BudgetUpdater, ConfigCache, MySQL Utility
//data "aws_ami" "amazon_linux2_x86_ami" {
//  most_recent = true
//  owners      = ["self", "amazon", "715852559442"]
//
//  filter {
//    name   = "name"
//    values = ["amzn2-ami-hvm-2.0.20220316.0-x86_64-gp2"]
//  }
//}

//data "aws_acm_certificate" "public_cert" {
//  domain   = "${var.public_cert_domain}"
//  statuses = ["ISSUED"]
//  types = ["${var.public_cert_issue_types}"]
//}

data "aws_acm_certificate" "rtb_public_cert" {
  domain   = var.rtb_cert_domain
  statuses = ["ISSUED"]
  types    = ["AMAZON_ISSUED"]
}

data "aws_route53_zone" "internal_route53_zone" {
  vpc_id = local.vpc_id
  name   = var.route53_zone_name
}

module "security_group" {
  source                                       = "../../components/security_group"
  alks_account                                 = var.alks_account
  vpc_name                                     = var.vpc_name
  vpc_id                                       = local.vpc_id
  tag_environment                              = var.tag_environment
  elasticache_sg_name                          = var.elasticache_sg_name
  redis_port                                   = var.redis_port
  mx4j_port                                    = var.mx4j_port
  app_metrics_port                             = var.app_metrics_port
  app_ssh_port                                 = var.app_ssh_port
  mysql_port                                   = var.mysql_port
  elasticache_subnet_group_name                = var.elasticache_subnet_group_name
  zeppelin_security_group_prevent_destroy      = var.load_balancer_security_group_prevent_destroy
  load_balancer_security_group_prevent_destroy = var.load_balancer_security_group_prevent_destroy
  configcache_security_group_prevent_destroy   = var.configcache_security_group_prevent_destroy
  ads_pix_security_group_prevent_destroy       = var.ads_pix_security_group_prevent_destroy
  txcache_security_group_prevent_destroy       = var.txcache_security_group_prevent_destroy
  datadog_security_group_prevent_destroy       = var.datadog_security_group_prevent_destroy
  userdatacache_r6_subnet_group_name           = var.userdatacache_r6_subnet_group_name
  vt_office_ip                                 = var.vt_office_ip
  on_prem_range                                = var.on_prem_range
  config_subnet_group_name                     = var.config_subnet_group_name
  budget_subnet_group_name                     = var.budget_subnet_group_name
  impression_subnet_group_name                 = var.impression_subnet_group_name
  standard_private_subnets                     = var.standard_private_subnets
  extra_private_subnets                        = var.extra_private_subnets
  elasticache_private_subnets                  = var.elasticache_private_subnets
  cox_ghe_ip_addresses                         = var.cox_ghe_ip_addresses
  public_subnets                               = var.public_subnets
  retool_app_name                              = var.retool_app_name
  east_standard_private_subnets                = var.east_standard_private_subnets
  west_standard_private_subnets                = var.west_standard_private_subnets
  all_private_subnets                          = var.all_private_subnets
  workload_mapping                             = var.workload_mapping

  providers = {
    aws.east = aws.east
    aws.west = aws.west
  }
}

// SSM Documents
module "ssm_document_app_ansible" {
  source        = "../../components/ssm_document"
  document_name = "RTB-RunAnsiblePlaybook"
  document_type = "Command"
}

module "ssm_document_app_ansible_install_ansible" {
  source        = "../../components/ssm_document"
  document_name = "RTB-RunAnsiblePlaybookInstallAnsible"
  document_type = "Command"
}

# this is compatible with amazon linux 1, 2 on both x86_64 and arm64
module "ssm_document_app_ansible_with_ansible" {
  source        = "../../components/ssm_document"
  document_name = "RTB-RunAnsiblePlaybookWithAnsible"
  document_type = "Command"
}

module "ssm_document_ptarchive_impressiondb" {
  source        = "../../components/ssm_document"
  document_name = "RTB-PTARCHIVER-ImpressionDB"
  document_type = "Command"
}

module "ssm_document_ptarchive_generic" {
  source        = "../../components/ssm_document"
  document_name = "RTB-PTARCHIVER"
  document_type = "Command"
}

module "ssm_document_iotop_log" {
  source        = "../../components/ssm_document"
  document_name = "RTB-Log-iotop"
  document_type = "Command"
}

module "ssm_document_noop" {
  source        = "../../components/ssm_document"
  document_name = "RTB-NoOp"
  document_type = "Command"
}

module "ssm_document_smtp_setup" {
  source        = "../../components/ssm_document"
  document_name = "RTB-SMTPSetup"
  document_type = "Command"
}

module "ssm_document_codedeploy_cleanup" {
  source        = "../../components/ssm_document"
  document_name = "RTB-CodeDeployCleanup"
  document_type = "Command"
}

module "ssm_document_hollow_ebs_mount" {
  source        = "../../components/ssm_document"
  document_name = "RTB-MountHollowVolume"
  document_type = "Command"
}

//RDS

module "impression_single_instance_rds" {
  source                  = "../../components/rds"
  app_name                = var.impression_single_instance_app_name
  enable                  = var.impression_single_instance_rds_enable
  route53_zone_id         = data.aws_route53_zone.internal_route53_zone.id
  product                 = var.product
  platform                = var.platform
  app_tag                 = var.impression_app_tag
  tag_environment         = var.tag_environment
  security_group_id       = module.security_group.rds_sg_id
  rds_enhanced_role_arn   = data.terraform_remote_state.alks.outputs.enhanced_role_arn
  zone_name               = var.route53_zone_name
  app_instance_type       = var.impression_single_instance_type
  kms_payload             = var.impression_kms_payload
  allocated_storage       = var.impression_single_allocated_storage
  storage_type            = var.impression_storage_type
  engine                  = var.impression_engine
  engine_version          = var.impression_engine_version
  username                = var.impression_username
  maintenance_window      = var.impression_maintenance_window
  backup_window           = var.impression_backup_window
  backup_retention_period = var.impression_backup_retention_period
  monitoring_interval     = var.impression_monitoring_interval
  mysql_family            = var.impression_mysql_family
  innodb_log_buffer_size  = var.impression_innodb_log_buffer_size
  innodb_log_file_size    = var.impression_innodb_log_file_size
  subnet_group_name       = var.impression_subnet_group_name
  multi_az                = var.rds_multi_az
  chain_identifier        = var.impression_rds_chain_identifier
  region                  = var.region
  workload_id             = lookup(var.workload_mapping, var.bidder_app_name, "")
}

resource "aws_db_instance_automated_backups_replication" "cross_region_snapshot" {
  count                  = var.tag_environment == "prod" ? length(local.rds_snapshot_replication_targets[var.region]) : 0
  source_db_instance_arn = local.rds_snapshot_replication_targets[var.region][count.index]
  retention_period       = 14
}

module "budget_rds_read_replicas" {
  source                = "../../components/rds_read_replica"
  app_instance_type     = var.budget_instance_type
  app_name              = var.budget_app_name
  identifier            = "${var.budget_app_name}-80"
  rds_master            = var.budget_rds_master
  storage_type          = var.budget_storage_type
  maintenance_window    = var.budget_maintenance_window
  monitoring_interval   = var.budget_monitoring_interval
  parameter_group       = var.budget_parameter_group
  subnet_group_name     = var.budget_subnet_group_name
  read_replicas         = var.budget_read_replicas
  ttl                   = var.budget_ttl
  route53_zone_id       = data.aws_route53_zone.internal_route53_zone.id
  product               = var.product
  platform              = var.platform
  tag_environment       = var.tag_environment
  zone_name             = var.route53_zone_name
  multi_az              = var.rds_multi_az
  security_group_id     = module.security_group.rds_sg_id
  rds_enhanced_role_arn = data.terraform_remote_state.alks.outputs.enhanced_role_arn
  chain_identifier      = var.budget_rds_chain_identifier
  workload_id           = lookup(var.workload_mapping, var.budget_app_name, "")
}

module "config_east_rds_read_replicas" {
  source                = "../../components/rds_read_replica"
  app_instance_type     = var.config_instance_type
  app_name              = var.config_app_name
  identifier            = "${var.config_app_name}-80"
  rds_master            = var.config_east_rds_master
  storage_type          = var.config_storage_type
  maintenance_window    = var.config_maintenance_window
  monitoring_interval   = var.config_monitoring_interval
  parameter_group       = var.config_parameter_group
  subnet_group_name     = var.config_subnet_group_name
  read_replicas         = var.config_east_read_replicas
  ttl                   = var.config_ttl
  route53_zone_id       = data.aws_route53_zone.internal_route53_zone.id
  product               = var.product
  platform              = var.platform
  zone_name             = var.route53_zone_name
  multi_az              = var.rds_multi_az
  tag_environment       = var.tag_environment
  security_group_id     = module.security_group.rds_sg_id
  rds_enhanced_role_arn = data.terraform_remote_state.alks.outputs.enhanced_role_arn
  chain_identifier      = var.config_rds_chain_identifier
  workload_id           = lookup(var.workload_mapping, var.config_services_shortname, "")
}

// Notify for all RDS instances
resource "aws_db_event_subscription" "rds_notifications" {
  count     = var.rds_notifications_enable ? 1 : 0
  name      = "rds-notifications"
  sns_topic = module.notifications_sns.sns_topic_arn
  tags = {
    name            = "rds-notifications"
    platform        = "ddc-advertising"
    product         = "rtb"
    slackContact    = "+rtb-issues"
    environment     = var.tag_environment
    "coxauto:ci-id" = lookup(var.workload_mapping, "rtb-common", "")
  }
}

resource "aws_dynamodb_table" "rtb_locks" {
  provider = aws

  name           = "rtb-application-locks"
  hash_key       = "key"
  read_capacity  = 20
  write_capacity = 20

  attribute {
    name = "key"
    type = "S"
  }

  tags = {
    platform              = "ddc-advertising"
    product               = "rtb"
    application           = "rtb-locks"
    slackContact          = "+rtb-issues"
    application-component = "dynamodb"
    environment           = var.tag_environment
    "coxauto:ci-id"       = lookup(var.workload_mapping, var.bidder_app_name, "")
  }
}

// datadog_rds_lambda
module "datadog_rds_lambda" {
  source = "../../components/snowflakes/datadog_rds_lambda"

  name           = var.datadog_rds_lambda_name
  role_arn       = data.terraform_remote_state.alks.outputs.datadog_rds_lambda_role_arn
  ssm_param_name = var.datadog_rds_lambda_ssm_param_name
  region         = var.region
}

data "aws_caller_identity" "current" {
}

// SNS
module "critical_sns" {
  source           = "../../components/sns"
  sns_topic_name   = var.sns_critical_topic_name
  sns_display_name = var.sns_critical_display_name
  region           = var.region
  tag_environment  = var.tag_environment
  workload_id      = "CI0641596"
}

module "daytime_sns" {
  source           = "../../components/sns"
  sns_topic_name   = var.sns_daytime_topic_name
  sns_display_name = var.sns_daytime_display_name
  region           = var.region
  tag_environment  = var.tag_environment
  workload_id      = "CI0641596"
}

module "notifications_sns" {
  source           = "../../components/sns"
  sns_topic_name   = var.sns_notifications_topic_name
  sns_display_name = var.sns_notifications_display_name
  region           = var.region
  tag_environment  = var.tag_environment
  workload_id      = "CI0641596"
}

module "control_sns" {
  source           = "../../components/sns"
  sns_topic_name   = var.sns_control_topic_name
  sns_display_name = var.sns_control_display_name
  region           = var.region
  tag_environment  = var.tag_environment
  workload_id      = "CI0641596"
}

module "mediaguard_sns" {
  source           = "../../components/sns"
  sns_topic_name   = var.sns_mediaguard_topic_name
  sns_display_name = var.sns_mediaguard_display_name
  region           = var.region
  tag_environment  = var.tag_environment
  workload_id      = lookup(var.workload_mapping, var.bidder_app_name, "")
}

module "b_i_l_t_snowflake_sns" {
  source           = "../../components/sns"
  sns_topic_name   = var.sns_b_i_l_t_snowflake_integration_topic_name
  sns_display_name = var.sns_b_i_l_t_snowflake_integration_display_name
  region           = var.region
  policy           = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "s3PublishesToSnsTopic",
      "Principal": {
       "Service": "s3.amazonaws.com"
      },
      "Action": [
        "SNS:Publish"
      ],
      "Effect": "Allow",
      "Resource": [
        "arn:aws:sns:${var.region}:${var.alks_account_id}:${var.sns_b_i_l_t_snowflake_integration_topic_name}"
      ],
      "Condition": {
        "ArnLike": { "aws:SourceArn": "arn:aws:s3:*:*:${var.alks_account}-business-intelligence-long-term"}
      }
    },
    {
      "Sid": "allowSnowflakeSqsToSubscribeToOurSns",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::021712061285:user/qwyl-s-vass1253"
      },
      "Action": [
        "sns:Subscribe"
      ],
      "Resource": [
        "arn:aws:sns:${var.region}:${var.alks_account_id}:${var.sns_b_i_l_t_snowflake_integration_topic_name}"
      ]
    }
  ]
}
EOF

  tag_environment = var.tag_environment
  workload_id     = lookup(var.workload_mapping, "bi", "")
}

module "userdatacache_r6" {
  source   = "../../components/elasticache_redis_cluster"
  app_name = "userdatacache_r6"

  notification_sns_topic_arn    = module.notifications_sns.sns_topic_arn
  snapshot_window               = var.userdatacache_snapshot_window
  num_slaves_per_master         = var.userdatacache_num_slaves_per_master
  subnet_group_name             = module.security_group.userdatacache_r6_subnet_group_name
  replication_group_description = "User Data R6 Cache Cluster"
  replication_group_id          = var.userdatacache_r6_replication_group_id
  maint_window                  = var.userdatacache_maint_window
  node_type                     = var.userdatacache_r6_instance_type
  tag_environment               = var.tag_environment
  port                          = var.redis_port
  security_group_id             = module.security_group.elasticache_redis_sg_id
  snapshot_retention            = var.userdatacache_snapshot_retention
  num_masters                   = var.userdatacache_r6_num_masters
  redis_engine_version          = var.userdatacache_r6_redis_engine_version
  redis_param_group_name        = var.userdatacache_r6_redis_param_group_name
  workload_id                   = lookup(var.workload_mapping, var.bidder_app_name, "")
}

module "userdatacache_r6_route53" {
  source = "../../components/route53_single"

  vpc_id = local.vpc_id

  name              = "userdatacache_r6"
  prevent_destroy   = "true"
  route53_zone_name = var.route53_zone_name
  record_type       = "CNAME"
  records           = [module.userdatacache_r6.endpoint]
}

resource "aws_elasticache_parameter_group" "elasticache_cluster_enabled_activedefrag_params" {
  name        = "redis6x-cluster-activedefrag"
  family      = "redis6.x"
  description = "Based on default.redis6.x"

  parameter {
    name  = "cluster-enabled"
    value = "yes"
  }
  // Enabled active memory defragmentation
  parameter {
    name  = "activedefrag"
    value = "yes"
  }
  // Minimal effort for defrag in CPU percentage
  parameter {
    name  = "active-defrag-cycle-min"
    value = "1"
  }
  // Maximal effort for defrag in CPU percentage
  parameter {
    name  = "active-defrag-cycle-max"
    value = "10"
  }
  // Minimum percentage of fragmentation to start active defrag
  parameter {
    name  = "active-defrag-threshold-lower"
    value = "10"
  }
}

module "txcachecluster" {
  source   = "../../components/elasticache_redis_cluster"
  app_name = "txcachecluster"

  notification_sns_topic_arn    = module.notifications_sns.sns_topic_arn
  snapshot_window               = var.txcachecluster_snapshot_window
  num_slaves_per_master         = var.txcachecluster_num_slaves_per_master
  subnet_group_name             = module.security_group.elasticache_subnet_group_name
  replication_group_description = "Transaction Cache Cluster"
  replication_group_id          = var.txcachecluster_replication_group_id
  maint_window                  = var.txcachecluster_maint_window
  node_type                     = var.txcachecluster_instance_type
  tag_environment               = var.tag_environment
  port                          = var.redis_port
  security_group_id             = module.security_group.elasticache_redis_sg_id
  snapshot_retention            = var.txcachecluster_snapshot_retention
  num_masters                   = var.txcachecluster_num_masters
  redis_engine_version          = var.txcachecluster_redis_engine_version
  redis_param_group_name        = aws_elasticache_parameter_group.elasticache_cluster_enabled_activedefrag_params.name
  workload_id                   = lookup(var.workload_mapping, var.bidder_app_name, "")
}

module "txcluster_route53" {
  source = "../../components/route53_single"

  vpc_id = local.vpc_id

  name              = "rtb-txcluster"
  prevent_destroy   = "true"
  route53_zone_name = var.route53_zone_name
  record_type       = "CNAME"
  records           = [module.txcachecluster.endpoint]
}

module "opt_out_cloudfront" {
  source = "../../components/cloudfront"
}

// ADS

module "ads_instances_amzn2" {
  source                     = "../../components/ec2"
  ssh_key_name               = var.ssh_key_name_sote
  route53_zone_name          = var.route53_zone_name
  tag_environment            = var.tag_environment
  app_security_group_id      = module.security_group.ads_pix_sg_id
  prevent_destroy            = var.ads_instance_prevent_destroy
  app_instance_type          = var.tag_environment == "prod" ? "r6g.2xlarge" : var.ads_instance_type
  num_app_instances          = 1
  app_hostname_prefix        = var.ads_app_name
  app_name                   = var.ads_app_name
  iam_role                   = var.ads_iam_role
  enable_enhanced_monitoring = var.ads_enable_enhanced_monitoring
  region                     = var.region
  ami_id                     = local.ads_ami[var.region]
  private_subnet_ids         = local.private_subnet_ids
  subnet_az                  = local.private_subnet_azs
  vpc_id                     = local.vpc_id
  workload_id                = lookup(var.workload_mapping, var.ads_app_name, "")
  architecture               = "aarch64"
  add_static_instance_tag    = true
  coxauto_scan_reboot_tag_key = var.coxauto_scan_reboot_tag_key
  ebs_root_device_size_gigabytes = 12
}

module "ads_impression_state_sqs" {
  source                      = "../../components/sqs"
  delay_seconds               = "0"
  max_message_size            = "262144" // 256kb
  message_retention_seconds   = "600"    // 10 mins
  queue_name                  = "impression-state.fifo"
  receive_wait_time_seconds   = 20 // we have a scheduler running every 60 secs
  redrive_policy              = ""
  tag_environment             = var.tag_environment
  content_based_deduplication = true
  fifo_queue                  = true
  app_name                    = "ads_pix"
  region                      = var.region
  workload_id                 = lookup(var.workload_mapping, var.pix_app_name, "")
}

module "ads_impression_state_sqs_standard" {
  source                    = "../../components/sqs"
  delay_seconds             = "0"
  max_message_size          = "262144" // 256kb
  message_retention_seconds = "600"    // 10 mins
  queue_name                = "impression-state"
  receive_wait_time_seconds = 20 // we have a scheduler running every 60 secs
  redrive_policy            = ""
  tag_environment           = var.tag_environment
  app_name                  = "ads_pix"
  region                    = var.region
  workload_id               = lookup(var.workload_mapping, var.pix_app_name, "")
}

module "ads_asg" {
  source              = "../../components/ec2_asg"
  min_size            = var.ads_min_asg_size
  max_size            = var.ads_max_asg_size
  ami_id              = local.ads_ami[var.region]
  app_name            = var.ads_app_name
  target_group_arns   = [module.ads_alb.alb_target_group_arn]
  codedeploy_role_arn = data.terraform_remote_state.alks.outputs.codedeploy_role_arn
  iam_role            = var.ads_iam_role
  instance_type       = var.tag_environment == "prod" ? "r6g.2xlarge" : "t3.micro"
  key_name            = var.ssh_key_name_sote
  security_group_ids  = [module.security_group.ads_pix_sg_id]
  private_subnet_ids  = local.private_subnet_ids
  subnet_az           = local.private_subnet_azs
  vpc_id              = local.vpc_id
  region              = var.region
  num_app_instances   = var.num_ads_instances
  tag_environment     = var.tag_environment

  build_canary_asg    = "true"
  canary_asg_min_size = var.big3_canary_asg_min_size
  canary_asg_max_size = var.big3_canary_asg_max_size

  workload_id  = lookup(var.workload_mapping, var.ads_app_name, "")
  architecture = "aarch64"
}

data "aws_arn" "ads_asg_arn" {
  arn = module.ads_alb.alb_arn
}

data "aws_arn" "ads_asg_target_group_arn" {
  arn = module.ads_alb.alb_target_group_arn
}

resource "aws_autoscaling_policy" "ads_scaling_policy" {
  name                   = "rtb-ads-asg-policy"
  autoscaling_group_name = module.ads_asg.asg_name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    target_value = var.ads_target_requests_per_min

    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"

      // https://docs.aws.amazon.com/autoscaling/plans/APIReference/API_PredefinedScalingMetricSpecification.html
      resource_label = "${replace(data.aws_arn.ads_asg_arn.resource, "/^loadbalancer\\//", "")}/${data.aws_arn.ads_asg_target_group_arn.resource}"
    }
  }
}

module "ads_association" {
  source               = "../../components/ssm_association"
  association_name     = "${var.ads_app_name}_app_ansible"
  ssm_document_name    = module.ssm_document_app_ansible_with_ansible.name
  association_schedule = ""

  association_parameters = {
    check       = "False"
    extravars   = "SSM=True application=${var.ads_app_name} codedeploy_agent=true java_live_version=java17"
    playbookurl = "s3://${var.devops_bucket_name}/${var.app_ansible_multiarch_amzlinux_key}"
  }

  multi_association = [{ "key" : "tag:application", "value" : var.ads_app_name }, { "key" : "tag:canary", "value" : "false" }]
}

module "ads_canary_association" {
  source               = "../../components/ssm_association"
  association_name     = "${var.ads_app_name}_app_multiarch_ansible"
  ssm_document_name    = module.ssm_document_app_ansible_with_ansible.name
  association_schedule = ""

  association_parameters = {
    check       = "False"
    extravars   = "SSM=True application=${var.ads_app_name} codedeploy_agent=true java_live_version=java17"
    playbookurl = "s3://${var.devops_bucket_name}/${var.app_ansible_multiarch_amzlinux_key}"
  }

  multi_association = [{ "key" : "tag:application", "value" : var.ads_app_name }, { "key" : "tag:canary", "value" : "true" }]
}

module "ads_elb" {
  source                           = "../../components/elb"
  tag_environment                  = var.tag_environment
  public_subnet_names              = var.elb_public_subnet_names
  elb_http_access_sg_id            = module.security_group.elb_http_access_sg_id
  domain                           = var.elb_domain
  internal_http_port               = var.ads_pix_internal_http_port
  external_http_port               = var.ads_pix_external_http_port
  https_port                       = var.ads_pix_https_port
  app_name                         = var.ads_app_name
  health_check_target              = var.ads_pix_health_check_target
  health_check_healthy_threshold   = var.ads_health_check_healthy_threshold
  health_check_interval            = var.ads_health_check_interval
  health_check_timeout             = var.ads_health_check_timeout
  health_check_unhealthy_threshold = var.ads_health_check_unhealthy_threshold
  instance_ids                     = module.ads_instances_amzn2.app_instance_ids
  prevent_destroy                  = var.ads_elb_prevent_destroy
  balanced_application             = "rtb-ads"
  access_logs_bucket               = var.access_logs_bucket
  enable_access_logs               = var.enable_access_logs
  workload_id                      = lookup(var.workload_mapping, var.ads_app_name, "")
  //  cert_arn                         = "${data.aws_acm_certificate.public_cert.arn}"
  cert_arn = var.esm_cert_2021_arn
}

resource "aws_wafv2_web_acl" "ads_waf_acl" {

  name        = "ads-alb-waf-acl-count"
  scope       = "REGIONAL"
  description = "Using WAF ACL to count xss attempts to our ads endpoint"
  default_action {
    allow {}
  }
  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "ads-alb-waf-acl-count"
    sampled_requests_enabled   = true
  }
  rule {
    name     = "inline-content-length-count"
    priority = 1
    action {
      block {}
    }
    statement {
      or_statement {
        statement {
          size_constraint_statement {
            comparison_operator = "GE"
            size                = 4096
            field_to_match {
              all_query_arguments {}
            }
            text_transformation {
              priority = 0
              type     = "HTML_ENTITY_DECODE"
            }
          }
        }
        statement {
          size_constraint_statement {
            comparison_operator = "GE"
            size                = 4096
            field_to_match {
              all_query_arguments {}
            }
            text_transformation {
              priority = 0
              type     = "URL_DECODE"
            }
          }
        }
      }

    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "inline-content-length-count"
      sampled_requests_enabled   = true
    }
  }
  rule {
    name     = "inline-cookie-header-count"
    priority = 2
    action {
      block {}
    }
    statement {
      or_statement {
        statement {
          xss_match_statement {
            field_to_match {
              single_header {
                name = "cookie"
              }
            }
            text_transformation {
              priority = 0
              type     = "HTML_ENTITY_DECODE"
            }
          }
        }
        statement {
          xss_match_statement {
            field_to_match {
              single_header {
                name = "cookie"
              }
            }
            text_transformation {
              priority = 0
              type     = "URL_DECODE"
            }
          }
        }
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "inline-cookie-header-count"
      sampled_requests_enabled   = true
    }
  }
  rule {
    name     = "inline-body-count"
    priority = 3
    action {
      block {}
    }
    statement {
      or_statement {
        statement {
          xss_match_statement {
            field_to_match {
              body {}
            }
            text_transformation {
              priority = 0
              type     = "HTML_ENTITY_DECODE"
            }
          }
        }
        statement {
          xss_match_statement {
            field_to_match {
              body {}
            }
            text_transformation {
              priority = 0
              type     = "URL_DECODE"
            }
          }
        }
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "inline-body-count"
      sampled_requests_enabled   = true
    }
  }
  rule {
    name     = "inline-query-string-count"
    priority = 4
    action {
      block {}
    }
    statement {
      or_statement {
        statement {
          xss_match_statement {
            field_to_match {
              query_string {}
            }
            text_transformation {
              priority = 0
              type     = "HTML_ENTITY_DECODE"
            }
          }
        }
        statement {
          xss_match_statement {
            field_to_match {
              query_string {}
            }
            text_transformation {
              priority = 0
              type     = "URL_DECODE"
            }
          }
        }
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "inline-query-string-count"
      sampled_requests_enabled   = true
    }
  }
  rule {
    name     = "inline-query-arguments-count"
    priority = 5
    action {
      block {}
    }
    statement {
      or_statement {
        statement {
          xss_match_statement {
            field_to_match {
              all_query_arguments {}
            }
            text_transformation {
              priority = 0
              type     = "HTML_ENTITY_DECODE"
            }
          }
        }
        statement {
          xss_match_statement {
            field_to_match {
              all_query_arguments {}
            }
            text_transformation {
              priority = 0
              type     = "URL_DECODE"
            }
          }
        }
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "inline-query-arguments-count"
      sampled_requests_enabled   = true
    }
  }
  rule {
    name     = "inline-uri-count"
    priority = 6
    action {
      block {}
    }
    statement {
      or_statement {
        statement {
          xss_match_statement {
            field_to_match {
              uri_path {}
            }
            text_transformation {
              priority = 0
              type     = "HTML_ENTITY_DECODE"
            }
          }
        }
        statement {
          xss_match_statement {
            field_to_match {
              uri_path {}
            }
            text_transformation {
              priority = 0
              type     = "URL_DECODE"
            }
          }
        }
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "inline-uri-count"
      sampled_requests_enabled   = true
    }
  }

  //  source = ""
}

module "ads_alb" {
  source = "../../components/alb"

  tag_environment   = var.tag_environment
  app_name          = var.ads_app_name
  alb_domain        = var.elb_domain
  internal_port     = var.ads_pix_internal_http_port
  lb_name           = "rtb-ads-alb-ddcwillt"
  target_protocol   = "HTTP"
  security_group_id = module.security_group.elb_http_access_sg_id

  instance_target_list = var.tag_environment == "prod" ? (var.region == "us-east-1" ? [module.ads_instances_amzn2.app_instance_ids[0]] : []) : module.ads_instances_amzn2.app_instance_ids

  vpc_id = local.vpc_id

  public_subnet_names = var.elb_public_subnet_names

  enable_http  = true
  enable_https = true

  alb_healthy_threshold           = var.ads_health_check_healthy_threshold
  alb_unhealthy_threshold         = var.ads_health_check_unhealthy_threshold
  alb_health_timeout              = var.ads_health_check_timeout
  alb_healthcheck_interval        = var.ads_health_check_interval
  alb_healthcheck_target_path     = "/?ESM_HEALTH_CHECK=true"
  alb_healthcheck_target_protocol = "HTTP"
  alb_monitoring_tag              = var.ads_alb_monitoring_tag
  workload_id                     = lookup(var.workload_mapping, var.ads_app_name, "")
  //  ssl_cert_arn                    = "${data.aws_acm_certificate.public_cert.arn}"
  ssl_cert_arn = var.esm_cert_2021_arn
  ssl_policy   = "ELBSecurityPolicy-FS-1-2-2019-08"
}

module "ads_route53" {
  source            = "../../components/route53"
  route53_zone_id   = data.aws_route53_zone.regional_rtb_vpc_zone.id
  route53_zone_name = data.aws_route53_zone.regional_rtb_vpc_zone.name
  hostname_prefix   = var.ads_app_name
  records           = join(",", module.ads_instances_amzn2.app_private_ip_addresses)
  record_type       = "A"
  num_instances     = length(module.ads_instances_amzn2.app_private_ip_addresses)
  prevent_destroy   = var.ads_route53_prevent_destroy
}


module "ads_lb_route53" {
  source             = "../../components/route53_elb_weighted_alias_geo"
  elb_weight         = var.ads_elb_weight
  alb_weight         = var.ads_alb_weight
  name               = var.ads_external_dns_name
  elb_dns_name       = module.ads_elb.dns_name
  zone_name          = var.esm1_zone_name
  elb_zone_id        = module.ads_elb.zone_id
  alb_dns_name       = module.ads_alb.alb_dns_name
  alb_zone_id        = module.ads_alb.alb_zone_id
  enable_alb         = true
  region_prefix      = var.ads_region_prefix
  geo_domain_name    = var.ads_geo_domain_name
  coast              = var.coast
  geo_record_region  = var.ads_geo_record_region
  app_name           = "ads"
  has_geo_record     = true
  external_http_port = var.ads_pix_external_http_port

  providers = {
    aws.east = aws.east
  }
}

module "ads_codedeploy" {
  source                      = "../../components/codedeploy"
  minimum_healthy_hosts_type  = var.ads_minimum_healthy_hosts_type
  minimum_healthy_hosts_value = var.ads_minimum_healthy_hosts_value
  single_canary               = var.ads_single_canary
  multi_canary                = var.ads_multi_canary
  static_group                = var.ads_static_group
  application                 = var.ads_app_name
  trigger_name                = var.ads_trigger_name
  auto_rollback_enabled       = var.ads_auto_rollback_enabled
  auto_rollback_events        = var.ads_auto_rollback_events
  trigger_events              = var.ads_trigger_events
  trigger_target_arn          = module.notifications_sns.sns_topic_arn
  service_role_arn            = data.terraform_remote_state.alks.outputs.codedeploy_role_arn
  instance_trigger_target_arn = module.rtb_deployment_notifications.sns_topic_arn
  tag_environment             = var.tag_environment
  region                      = var.region
}

// PIX

module "pix_instances_graviton_static" {
  source                     = "../../components/ec2"
  ssh_key_name               = var.ssh_key_name_sote
  route53_zone_name          = var.route53_zone_name
  tag_environment            = var.tag_environment
  app_security_group_id      = module.security_group.ads_pix_sg_id
  app_instance_type          = var.pix_instance_type
  num_app_instances          = var.num_pix_instances
  app_hostname_prefix        = var.pix_app_name
  app_name                   = var.pix_app_name
  prevent_destroy            = var.pix_instance_prevent_destroy
  iam_role                   = var.pix_iam_role
  enable_enhanced_monitoring = var.pix_enable_enhanced_monitoring

  ebs_root_device_size_gigabytes = var.pix_root_device_size_gigabytes

  region                     = var.region
  ami_id                     = local.pix_ami[var.region]
  private_subnet_ids         = local.private_subnet_ids
  subnet_az                  = local.private_subnet_azs
  vpc_id                     = local.vpc_id
  workload_id                = lookup(var.workload_mapping, var.pix_app_name, "")
  architecture               = "aarch64"
  add_static_instance_tag    = true
  coxauto_scan_reboot_tag_key = var.coxauto_scan_reboot_tag_key
}

module "pix_elb" {
  source                           = "../../components/elb"
  tag_environment                  = var.tag_environment
  public_subnet_names              = var.elb_public_subnet_names
  elb_http_access_sg_id            = module.security_group.elb_http_access_sg_id
  domain                           = var.elb_domain
  internal_http_port               = var.ads_pix_internal_http_port
  external_http_port               = var.ads_pix_external_http_port
  https_port                       = var.ads_pix_https_port
  app_name                         = var.pix_app_name
  health_check_target              = var.ads_pix_health_check_target
  health_check_healthy_threshold   = var.pix_health_check_healthy_threshold
  health_check_interval            = var.pix_health_check_interval
  health_check_timeout             = var.pix_health_check_timeout
  health_check_unhealthy_threshold = var.pix_health_check_unhealthy_threshold
  instance_ids                     = module.pix_instances_graviton_static.app_instance_ids
  prevent_destroy                  = var.pix_elb_prevent_destroy
  balanced_application             = "rtb-pix"
  access_logs_bucket               = var.access_logs_bucket
  enable_access_logs               = var.enable_access_logs
  workload_id                      = lookup(var.workload_mapping, var.pix_app_name, "")
  //  cert_arn                         = "${data.aws_acm_certificate.public_cert.arn}"
  cert_arn = var.esm_cert_2021_arn
}

module "pix_alb" {
  source = "../../components/alb"

  tag_environment   = var.tag_environment
  app_name          = var.pix_app_name
  alb_domain        = var.elb_domain
  internal_port     = var.ads_pix_internal_http_port
  lb_name           = "rtb-pix-alb"
  target_protocol   = "HTTP"
  security_group_id = module.security_group.elb_http_access_sg_id

  instance_target_list = var.tag_environment == "prod" ? (var.region == "us-east-1" ? [module.pix_instances_graviton_static.app_instance_ids[0]] : []) : module.pix_instances_graviton_static.app_instance_ids

  vpc_id = local.vpc_id

  public_subnet_names = var.elb_public_subnet_names

  enable_http  = true
  enable_https = true

  alb_healthy_threshold           = var.pix_health_check_healthy_threshold
  alb_unhealthy_threshold         = var.pix_health_check_unhealthy_threshold
  alb_health_timeout              = var.pix_health_check_timeout
  alb_healthcheck_interval        = var.pix_health_check_interval
  alb_healthcheck_target_path     = "/?ESM_HEALTH_CHECK=true"
  alb_healthcheck_target_protocol = "HTTP"
  alb_monitoring_tag              = var.pix_alb_monitoring_tag
  workload_id                     = lookup(var.workload_mapping, var.pix_app_name, "")
  //  ssl_cert_arn                    = "${data.aws_acm_certificate.public_cert.arn}"
  ssl_cert_arn = var.esm_cert_2021_arn
  ssl_policy   = "ELBSecurityPolicy-FS-1-2-2019-08"
}

module "pix_asg" {
  source              = "../../components/ec2_asg"
  min_size            = var.pix_min_asg_size
  max_size            = var.pix_max_asg_size
  ami_id              = local.pix_ami[var.region]
  app_name            = var.pix_app_name
  target_group_arns   = [module.pix_alb.alb_target_group_arn]
  codedeploy_role_arn = data.terraform_remote_state.alks.outputs.codedeploy_role_arn
  iam_role            = var.pix_iam_role
  instance_type       = var.pix_instance_type
  key_name            = var.ssh_key_name_sote
  security_group_ids  = [module.security_group.ads_pix_sg_id]
  private_subnet_ids  = local.private_subnet_ids
  subnet_az           = local.private_subnet_azs
  vpc_id              = local.vpc_id
  region              = var.region
  num_app_instances   = var.num_pix_instances
  tag_environment     = var.tag_environment

  build_canary_asg    = "true"
  canary_asg_min_size = var.big3_canary_asg_min_size
  canary_asg_max_size = var.big3_canary_asg_max_size

  workload_id  = lookup(var.workload_mapping, var.pix_app_name, "")
  architecture = "aarch64"
}

data "aws_arn" "pix_asg_arn" {
  arn = module.pix_alb.alb_arn
}

data "aws_arn" "pix_asg_target_group_arn" {
  arn = module.pix_alb.alb_target_group_arn
}

resource "aws_autoscaling_policy" "pix_scaling_policy" {
  name                   = "rtb-pix-asg-policy"
  autoscaling_group_name = module.pix_asg.asg_name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    target_value = var.pix_target_requests_per_min

    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"

      // https://docs.aws.amazon.com/autoscaling/plans/APIReference/API_PredefinedScalingMetricSpecification.html
      resource_label = "${replace(data.aws_arn.pix_asg_arn.resource, "/^loadbalancer\\//", "")}/${data.aws_arn.pix_asg_target_group_arn.resource}"
    }
  }
}

module "pix_lb_route53" {
  source             = "../../components/route53_elb_weighted_alias_geo"
  elb_weight         = var.pix_elb_weight
  alb_weight         = var.pix_alb_weight
  name               = var.pix_external_dns_name
  elb_dns_name       = module.pix_elb.dns_name
  zone_name          = var.esm1_zone_name
  elb_zone_id        = module.pix_elb.zone_id
  alb_dns_name       = module.pix_alb.alb_dns_name
  alb_zone_id        = module.pix_alb.alb_zone_id
  enable_alb         = true
  region_prefix      = var.pix_region_prefix
  geo_domain_name    = var.pix_geo_domain_name
  coast              = var.coast
  geo_record_region  = var.pix_geo_record_region
  app_name           = "pix"
  has_geo_record     = true
  external_http_port = var.ads_pix_external_http_port

  providers = {
    aws.east = aws.east
  }
}

data "aws_route53_zone" "regional_rtb_vpc_zone" {
  vpc_id = local.vpc_id
  name   = var.route53_zone_name
}

module "pix_route53" {
  source            = "../../components/route53"
  route53_zone_id   = data.aws_route53_zone.regional_rtb_vpc_zone.id
  route53_zone_name = data.aws_route53_zone.regional_rtb_vpc_zone.name
  records           = join(",", module.pix_instances_graviton_static.app_private_ip_addresses)
  record_type       = "A"
  num_instances     = var.num_pix_instances
  hostname_prefix   = var.pix_app_name
  prevent_destroy   = var.pix_route53_prevent_destroy
}


module "pix_association" {
  source            = "../../components/ssm_association"
  association_name  = "${var.pix_app_name}_app_ansible"
  ssm_document_name = module.ssm_document_app_ansible_with_ansible.name

  association_parameters = {
    check       = "False"
    extravars   = "SSM=True application=${var.pix_app_name} codedeploy_agent=true java_live_version=java17"
    playbookurl = "s3://${var.devops_bucket_name}/${var.app_ansible_multiarch_amzlinux_key}"
  }

  association_target_key    = "tag:application"
  association_target_values = [var.pix_app_name]

  association_schedule = ""
}

module "pix_graviton_ssm_association" {
  source            = "../../components/ssm_association"
  association_name  = "${var.pix_app_name}_app_ansible_graviton"
  ssm_document_name = module.ssm_document_app_ansible_install_ansible.name
  architecture_key  = "aarch64"

  association_parameters = {
    check       = "False"
    extravars   = "SSM=True application=${var.pix_app_name} codedeploy_agent=true java_live_version=java17"
    playbookurl = "s3://${var.devops_bucket_name}/${var.app_ansible_multiarch_amzlinux_key}"
  }

  association_target_key    = "tag:application"
  association_target_values = [var.pix_app_name]

  association_schedule = ""
}

module "pix_graviton_ssm_association_asg" {
  source            = "../../components/ssm_association"
  association_name  = "${var.pix_app_name}_app_ansible_graviton"
  ssm_document_name = module.ssm_document_app_ansible_install_ansible.name
  architecture_key  = "aarch64"

  association_parameters = {
    check       = "False"
    extravars   = "SSM=True application=${var.pix_app_name} codedeploy_agent=true java_live_version=java17"
    playbookurl = "s3://${var.devops_bucket_name}/${var.app_ansible_multiarch_amzlinux_key}"
  }

  association_target_key    = "tag:application"
  association_target_values = ["rtb-pix-graviton"]

  association_schedule = ""
}

module "pix_codedeploy" {
  source                      = "../../components/codedeploy"
  minimum_healthy_hosts_type  = var.pix_minimum_healthy_hosts_type
  minimum_healthy_hosts_value = var.pix_minimum_healthy_hosts_value
  single_canary               = var.pix_single_canary
  multi_canary                = var.pix_multi_canary
  static_group                = var.pix_static_group
  application                 = var.pix_app_name
  trigger_name                = var.pix_trigger_name
  auto_rollback_enabled       = var.pix_auto_rollback_enabled
  auto_rollback_events        = var.pix_auto_rollback_events
  trigger_events              = var.pix_trigger_events
  trigger_target_arn          = module.notifications_sns.sns_topic_arn
  service_role_arn            = data.terraform_remote_state.alks.outputs.codedeploy_role_arn
  instance_trigger_target_arn = module.rtb_deployment_notifications.sns_topic_arn
  tag_environment             = var.tag_environment
  region                      = var.region
}

// BIDDER
// begin bidder ALB
module "bidder_alb_x01" {
  source = "../../components/alb"

  tag_environment   = var.tag_environment
  app_name          = var.bidder_app_name
  alb_domain        = var.elb_domain
  internal_port     = var.bidder_internal_http_port
  lb_name           = "rtb-bidder-x01-alb"
  target_protocol   = "HTTP"
  security_group_id = module.security_group.bidder_elb_http_access_sg_id
  workload_id       = lookup(var.workload_mapping, var.bidder_app_name, "")

  instance_target_list = module.bidder_instances.app_instance_ids

  vpc_id                          = local.vpc_id
  public_subnet_names             = var.elb_public_subnet_names
  enable_http                     = true
  enable_https                    = true
  enable_8443                     = true
  alb_healthy_threshold           = var.bidder_health_check_healthy_threshold
  alb_unhealthy_threshold         = var.bidder_health_check_unhealthy_threshold
  alb_health_timeout              = var.bidder_health_check_timeout
  alb_healthcheck_interval        = var.bidder_health_check_interval
  alb_healthcheck_target_path     = "/?ESM_HEALTH_CHECK=true"
  alb_healthcheck_target_protocol = "HTTP"
  alb_monitoring_tag              = "${var.bidder_app_name}-x01-alb"
  ssl_cert_arn                    = var.esm_cert_2021_arn

  providers = {
    aws.east = aws.east
  }
}

module "bidder_alb_x01_route53" {
  source = "../../components/route53_alb_weighted_alias_geo"

  app_name           = var.bidder_app_name
  coast              = var.coast
  external_http_port = var.bidder_external_http_port
  has_geo_record     = false
  geo_domain_name    = var.bidder_geo_domain_name
  geo_record_region  = var.bidder_geo_record_region
  name               = var.rtba01_external_dns_name
  region_prefix      = var.rtba01_region_prefix
  zone_name          = var.esm1_zone_name

  alb_weight   = var.bidder_alb_weight
  alb_dns_name = module.bidder_alb_x01.alb_dns_name
  alb_zone_id  = module.bidder_alb_x01.alb_zone_id

  providers = {
    aws.east = aws.east
  }
}
// end bidder ALB

module "bidder_asg" {
  source   = "../../components/ec2_asg"
  min_size = var.bidder_min_asg_size
  max_size = var.bidder_max_asg_size
  ami_id   = local.bidder_ami[var.region]
  app_name = var.bidder_app_name

  workload_id         = lookup(var.workload_mapping, var.bidder_app_name, "")
  target_group_arns   = [module.bidder_alb_x01.alb_target_group_arn, module.bidder_x09_alb.alb_target_group_arn, module.bidder_x10_alb.alb_target_group_arn, module.bidder_x11_alb.alb_target_group_arn, module.bidder_x12_alb.alb_target_group_arn]
  classic_elbs        = [module.bidder_elb_x09.elb_name, module.bidder_elb_x10.elb_name, module.bidder_elb_x11.elb_name, module.bidder_elb_x12.elb_name]
  codedeploy_role_arn = data.terraform_remote_state.alks.outputs.codedeploy_role_arn
  iam_role            = data.terraform_remote_state.alks.outputs.bidder_role_name
  instance_type       = var.bidder_instance_type
  key_name            = var.ssh_key_name_sote
  security_group_ids  = [module.security_group.bidder_sg_id]
  private_subnet_ids  = slice(local.private_subnet_ids, 0, length(var.private_subnets)) // ugh just use all subnets in future
  subnet_az           = local.private_subnet_azs
  vpc_id              = local.vpc_id
  region              = var.region
  num_app_instances   = var.num_bidder_instances
  tag_environment     = var.tag_environment

  enable_termination_notifications = false

  asg_health_check_grace_period = 480
  asg_default_cooldown          = 600

  build_canary_asg    = "true"
  canary_asg_min_size = 0

  canary_asg_max_size = var.big3_canary_asg_max_size

  extra_volume_size = var.bidder_hollow_volume_size
  extra_volume_type = "gp2"
  architecture      = "aarch64"

  deploy_config_use_minimum_healthy_hosts   = true
  deploy_config_minimum_healthy_hosts_type  = var.bidder_minimum_healthy_hosts_type
  deploy_config_minimum_healthy_hosts_value = var.bidder_minimum_healthy_hosts_value
  health_check_type                         = "ELB"
  override_instance_hostname                = true
}

resource "aws_autoscaling_policy" "bidder_scaling_policy" {
  name                   = "rtb-bidder-asg-policy"
  autoscaling_group_name = module.bidder_asg.asg_name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    target_value = var.bidder_target_requests_per_min

    customized_metric_specification {
      # ALBs
      metrics {
        label = "rtb-bidder-x01-alb request count"
        id    = "albx01"
        metric_stat {
          metric {
            namespace   = "AWS/ApplicationELB"
            metric_name = "RequestCount"
            dimensions {
              name  = "LoadBalancer"
              value = module.bidder_alb_x01.alb_arn_suffix
            }
          }
          stat = "Sum"
        }
        return_data = false
      }
      metrics {
        label = "rtb-bidder-x10-alb request count"
        id    = "albx10"
        metric_stat {
          metric {
            namespace   = "AWS/ApplicationELB"
            metric_name = "RequestCount"
            dimensions {
              name  = "LoadBalancer"
              value = module.bidder_x10_alb.alb_arn_suffix
            }
          }
          stat = "Sum"
        }
        return_data = false
      }
      metrics {
        label = "rtb-bidder-x11-alb request count"
        id    = "albx11"
        metric_stat {
          metric {
            namespace   = "AWS/ApplicationELB"
            metric_name = "RequestCount"
            dimensions {
              name  = "LoadBalancer"
              value = module.bidder_x11_alb.alb_arn_suffix
            }
          }
          stat = "Sum"
        }
        return_data = false
      }
      metrics {
        label = "rtb-bidder-x12-alb request count"
        id    = "albx12"
        metric_stat {
          metric {
            namespace   = "AWS/ApplicationELB"
            metric_name = "RequestCount"
            dimensions {
              name  = "LoadBalancer"
              value = module.bidder_x12_alb.alb_arn_suffix
            }
          }
          stat = "Sum"
        }
        return_data = false
      }
      metrics {
        label = "rtb-bidder-x09-alb request count"
        id    = "albx09"
        metric_stat {
          metric {
            namespace   = "AWS/ApplicationELB"
            metric_name = "RequestCount"
            dimensions {
              name  = "LoadBalancer"
              value = module.bidder_x09_alb.alb_arn_suffix
            }
          }
          stat = "Sum"
        }
        return_data = false
      }
      # ELBs
      metrics {
        label = "rtb-bidder-x09-elb request count"
        id    = "elbx09"
        metric_stat {
          metric {
            namespace   = "AWS/ELB"
            metric_name = "RequestCount"
            dimensions {
              name  = "LoadBalancerName"
              value = module.bidder_elb_x09.elb_name
            }
          }
          stat = "Sum"
        }
        return_data = false
      }
      metrics {
        label = "rtb-bidder-x10-elb request count"
        id    = "elbx10"
        metric_stat {
          metric {
            namespace   = "AWS/ELB"
            metric_name = "RequestCount"
            dimensions {
              name  = "LoadBalancerName"
              value = module.bidder_elb_x10.elb_name
            }
          }
          stat = "Sum"
        }
        return_data = false
      }
      metrics {
        label = "rtb-bidder-x11-elb request count"
        id    = "elbx11"
        metric_stat {
          metric {
            namespace   = "AWS/ELB"
            metric_name = "RequestCount"
            dimensions {
              name  = "LoadBalancerName"
              value = module.bidder_elb_x11.elb_name
            }
          }
          stat = "Sum"
        }
        return_data = false
      }
      metrics {
        label = "rtb-bidder-x12-elb request count"
        id    = "elbx12"
        metric_stat {
          metric {
            namespace   = "AWS/ELB"
            metric_name = "RequestCount"
            dimensions {
              name  = "LoadBalancerName"
              value = module.bidder_elb_x12.elb_name
            }
          }
          stat = "Sum"
        }
        return_data = false
      }
      metrics {
        label = "Number of instances in ASG"
        id    = "asg"
        metric_stat {
          metric {
            namespace   = "AWS/AutoScaling"
            metric_name = "GroupInServiceInstances"
            dimensions {
              name  = "AutoScalingGroupName"
              value = module.bidder_asg.asg_name
            }
          }
          stat = "Sum"
        }
        return_data = false
      }
      metrics {
        label       = "Total request count per instance in ASG"
        id          = "total"
        expression  = "(albx01 + albx09 + albx10 + albx11 + albx12 + elbx09 + elbx10 + elbx11 + elbx12) / (asg + ${var.num_bidder_instances}) "
        return_data = true
      }
    }
  }
}

module "bidder_instances" {
  source                = "../../components/ec2"
  ssh_key_name          = var.ssh_key_name_sote
  route53_zone_name     = var.route53_zone_name
  tag_environment       = var.tag_environment
  app_security_group_id = module.security_group.bidder_sg_id
  app_instance_type     = var.bidder_instance_type
  num_app_instances     = var.num_bidder_instances

  app_hostname_prefix            = var.bidder_app_name
  app_name                       = var.bidder_app_name
  prevent_destroy                = var.bidder_instance_prevent_destroy
  iam_role                       = data.terraform_remote_state.alks.outputs.bidder_role_name
  enable_enhanced_monitoring     = var.bidder_enable_enhanced_monitoring
  root_volume_type               = var.bidder_root_volume_type
  enable_extra_volume            = true
  extra_volume_size              = var.bidder_hollow_volume_size
  extra_volume_type              = "gp2"
  ebs_root_device_size_gigabytes = 16
  workload_id                    = lookup(var.workload_mapping, var.bidder_app_name, "")

  region                     = var.region
  ami_id                     = local.bidder_ami[var.region]
  private_subnet_ids         = slice(local.private_subnet_ids, 0, length(var.private_subnets)) // ugh just use all subnets in future
  subnet_az                  = local.private_subnet_azs
  vpc_id                     = local.vpc_id
  architecture               = "aarch64"
  add_static_instance_tag    = true
  coxauto_scan_reboot_tag_key = var.coxauto_scan_reboot_tag_key
}

module "bidder_graviton_ssm_association" {
  source            = "../../components/ssm_association"
  association_name  = "${var.bidder_app_name}_app_ansible_graviton"
  ssm_document_name = module.ssm_document_app_ansible_install_ansible.name
  architecture_key  = "aarch64"

  association_parameters = {
    check       = "False"
    extravars   = "SSM=True application=${var.bidder_app_name} codedeploy_agent=true java_live_version=java17"
    playbookurl = "s3://${var.devops_bucket_name}/${var.app_ansible_multiarch_amzlinux_key}"
  }

  association_target_key    = "tag:application"
  association_target_values = [var.bidder_app_name]

  association_schedule = ""
}

module "bidder_mount_extra_volume_association" {
  source            = "../../components/ssm_association"
  association_name  = "${var.bidder_app_name}_extra_volume"
  ssm_document_name = module.ssm_document_hollow_ebs_mount.name

  association_parameters = {
    noop = "none"
  }

  association_target_key    = "tag:application"
  association_target_values = [var.bidder_app_name]



  association_schedule = ""
}

module "bidder_log_iotop_association" {
  source            = "../../components/ssm_association"
  association_name  = "${var.bidder_app_name}_iotop_logger"
  ssm_document_name = module.ssm_document_iotop_log.name

  association_parameters = {
    noop = "none"
  }

  association_target_key    = "tag:application-component"
  association_target_values = ["rtb-bidder01", "rtb-bidder02", "rtb-bidder03", "rtb-bidder04", "rtb-bidder05"]



  association_schedule = ""
}

module "ssm_document_stop_bidding" {
  source        = "../../components/ssm_document"
  document_name = "RTB-StopBidding"
  document_type = "Command"
}

module "bidder_elb_x01" {
  source                           = "../../components/elb"
  tag_environment                  = var.tag_environment
  public_subnet_names              = var.elb_public_subnet_names
  elb_http_access_sg_id            = module.security_group.bidder_elb_http_access_sg_id
  domain                           = var.elb_domain
  internal_http_port               = var.bidder_internal_http_port
  external_http_port               = var.bidder_external_http_port
  https_port                       = var.bidder_https_port
  app_name                         = var.bidder_app_name
  health_check_target              = var.bidder_health_check_target
  health_check_healthy_threshold   = var.bidder_health_check_healthy_threshold
  health_check_interval            = var.bidder_health_check_interval
  health_check_timeout             = var.bidder_health_check_timeout
  health_check_unhealthy_threshold = var.bidder_health_check_unhealthy_threshold
  instance_ids                     = module.bidder_instances.app_instance_ids
  prevent_destroy                  = var.bidder_elb_prevent_destroy
  balanced_application             = "rtb-bidder"
  access_logs_bucket               = var.access_logs_bucket
  enable_access_logs               = var.enable_access_logs
  workload_id                      = lookup(var.workload_mapping, var.bidder_app_name, "")
  //  cert_arn                         = "${data.aws_acm_certificate.public_cert.arn}"
  cert_arn = var.esm_cert_2021_arn
}

module "bidder_elb_x09" {
  source                           = "../../components/elb"
  tag_environment                  = var.tag_environment
  public_subnet_names              = var.elb_public_subnet_names
  elb_http_access_sg_id            = module.security_group.bidder_elb_http_access_sg_id
  domain                           = var.elb_domain
  internal_http_port               = var.bidder_internal_http_port
  external_http_port               = var.bidder_external_http_port
  https_port                       = var.bidder_https_port
  app_name                         = "${var.bidder_app_name}-x09"
  health_check_target              = var.bidder_health_check_target
  health_check_healthy_threshold   = var.bidder_health_check_healthy_threshold
  health_check_interval            = var.bidder_health_check_interval
  health_check_timeout             = var.bidder_health_check_timeout
  health_check_unhealthy_threshold = var.bidder_health_check_unhealthy_threshold
  instance_ids                     = module.bidder_instances.app_instance_ids
  prevent_destroy                  = var.bidder_elb_prevent_destroy
  balanced_application             = "rtb-bidder"
  access_logs_bucket               = var.access_logs_bucket
  enable_access_logs               = var.enable_access_logs
  workload_id                      = lookup(var.workload_mapping, var.bidder_app_name, "")
  //  cert_arn                         = "${data.aws_acm_certificate.public_cert.arn}"
  cert_arn = var.esm_cert_2021_arn
}

module "bidder_x09_alb" {
  source = "../../components/alb"

  tag_environment   = var.tag_environment
  app_name          = var.bidder_app_name
  alb_domain        = var.elb_domain
  internal_port     = var.bidder_internal_http_port
  lb_name           = "rtb-bidder-x09-alb"
  target_protocol   = "HTTP"
  security_group_id = module.security_group.bidder_elb_http_access_sg_id

  instance_target_list = module.bidder_instances.app_instance_ids

  vpc_id = local.vpc_id

  public_subnet_names = var.elb_public_subnet_names

  enable_http  = true
  http_port    = 8080
  enable_https = true
  https_port   = 8443

  alb_healthy_threshold           = var.bidder_health_check_healthy_threshold
  alb_unhealthy_threshold         = var.bidder_health_check_unhealthy_threshold
  alb_health_timeout              = var.bidder_health_check_timeout
  alb_healthcheck_interval        = var.bidder_health_check_interval
  alb_healthcheck_target_path     = "/?ESM_HEALTH_CHECK=true"
  alb_healthcheck_target_protocol = "HTTP"
  alb_monitoring_tag              = var.bidder_alb_monitoring_tag
  workload_id                     = lookup(var.workload_mapping, var.bidder_app_name, "")
  dynamic_port                    = true
  //  ssl_cert_arn                    = "${data.aws_acm_certificate.public_cert.arn}"
  ssl_cert_arn = var.esm_cert_2021_arn
  ssl_policy   = "ELBSecurityPolicy-FS-1-2-2019-08"
}

module "bidder_alb_x09_route53" {
  source = "../../components/route53_alb_weighted_alias_geo"

  app_name           = var.bidder_app_name
  coast              = var.coast
  external_http_port = var.bidder_external_http_port
  has_geo_record     = false
  geo_domain_name    = var.bidder_geo_domain_name
  geo_record_region  = var.bidder_geo_record_region
  name               = var.rtba09_external_dns_name
  region_prefix      = var.rtba09_region_prefix
  zone_name          = var.esm1_zone_name

  alb_weight   = var.rtba09_alb_weight
  alb_dns_name = module.bidder_x09_alb.alb_dns_name
  alb_zone_id  = module.bidder_x09_alb.alb_zone_id

  providers = {
    aws.east = aws.east
  }
}

module "bidder_elb_x10" {
  source                           = "../../components/elb"
  tag_environment                  = var.tag_environment
  public_subnet_names              = var.elb_public_subnet_names
  elb_http_access_sg_id            = module.security_group.bidder_elb_http_access_sg_id
  domain                           = var.elb_domain
  internal_http_port               = var.bidder_internal_http_port
  external_http_port               = var.bidder_external_http_port
  https_port                       = var.bidder_https_port
  app_name                         = "${var.bidder_app_name}-x10"
  health_check_target              = var.bidder_health_check_target
  health_check_healthy_threshold   = var.bidder_health_check_healthy_threshold
  health_check_interval            = var.bidder_health_check_interval
  health_check_timeout             = var.bidder_health_check_timeout
  health_check_unhealthy_threshold = var.bidder_health_check_unhealthy_threshold
  instance_ids                     = module.bidder_instances.app_instance_ids
  prevent_destroy                  = var.bidder_elb_prevent_destroy
  balanced_application             = "rtb-bidder"
  access_logs_bucket               = var.access_logs_bucket
  enable_access_logs               = var.enable_access_logs
  workload_id                      = lookup(var.workload_mapping, var.bidder_app_name, "")
  //  cert_arn                         = "${data.aws_acm_certificate.public_cert.arn}"
  cert_arn = var.esm_cert_2021_arn
}

module "bidder_x10_alb" {
  source = "../../components/alb"

  tag_environment   = var.tag_environment
  app_name          = var.bidder_app_name
  alb_domain        = var.elb_domain
  internal_port     = var.bidder_internal_http_port
  lb_name           = "rtb-bidder-x10-alb"
  target_protocol   = "HTTP"
  security_group_id = module.security_group.bidder_elb_http_access_sg_id

  instance_target_list = module.bidder_instances.app_instance_ids

  vpc_id = local.vpc_id

  public_subnet_names = var.elb_public_subnet_names

  enable_http  = true
  http_port    = 8080
  enable_https = true
  https_port   = 8443

  alb_healthy_threshold           = var.bidder_health_check_healthy_threshold
  alb_unhealthy_threshold         = var.bidder_health_check_unhealthy_threshold
  alb_health_timeout              = var.bidder_health_check_timeout
  alb_healthcheck_interval        = var.bidder_health_check_interval
  alb_healthcheck_target_path     = "/?ESM_HEALTH_CHECK=true"
  alb_healthcheck_target_protocol = "HTTP"
  alb_monitoring_tag              = var.bidder_alb_monitoring_tag
  workload_id                     = lookup(var.workload_mapping, var.bidder_app_name, "")
  dynamic_port                    = true
  //  ssl_cert_arn                    = "${data.aws_acm_certificate.public_cert.arn}"
  ssl_cert_arn = var.esm_cert_2021_arn
  ssl_policy   = "ELBSecurityPolicy-FS-1-2-2019-08"
}

module "bidder_alb_x10_route53" {
  source = "../../components/route53_alb_weighted_alias_geo"

  app_name           = var.bidder_app_name
  coast              = var.coast
  external_http_port = var.bidder_external_http_port
  has_geo_record     = false
  geo_domain_name    = var.bidder_geo_domain_name
  geo_record_region  = var.bidder_geo_record_region
  name               = var.rtba10_external_dns_name
  region_prefix      = var.rtba10_region_prefix
  zone_name          = var.esm1_zone_name

  alb_weight   = var.rtba10_alb_weight
  alb_dns_name = module.bidder_x10_alb.alb_dns_name
  alb_zone_id  = module.bidder_x10_alb.alb_zone_id

  providers = {
    aws.east = aws.east
  }
}

module "bidder_x11_alb" {
  source = "../../components/alb"

  tag_environment   = var.tag_environment
  app_name          = var.bidder_app_name
  alb_domain        = var.elb_domain
  internal_port     = var.bidder_internal_http_port
  lb_name           = "rtb-bidder-x11-alb"
  target_protocol   = "HTTP"
  security_group_id = module.security_group.bidder_elb_http_access_sg_id

  instance_target_list = module.bidder_instances.app_instance_ids

  vpc_id = local.vpc_id

  public_subnet_names = var.elb_public_subnet_names

  enable_http  = true
  http_port    = 8080
  enable_https = true
  https_port   = 8443

  alb_healthy_threshold           = var.bidder_health_check_healthy_threshold
  alb_unhealthy_threshold         = var.bidder_health_check_unhealthy_threshold
  alb_health_timeout              = var.bidder_health_check_timeout
  alb_healthcheck_interval        = var.bidder_health_check_interval
  alb_healthcheck_target_path     = "/?ESM_HEALTH_CHECK=true"
  alb_healthcheck_target_protocol = "HTTP"
  alb_monitoring_tag              = var.bidder_alb_monitoring_tag
  workload_id                     = lookup(var.workload_mapping, var.bidder_app_name, "")
  dynamic_port                    = true
  //  ssl_cert_arn                    = "${data.aws_acm_certificate.public_cert.arn}"
  ssl_cert_arn = var.esm_cert_2021_arn
  ssl_policy   = "ELBSecurityPolicy-FS-1-2-2019-08"
}

module "bidder_alb_x11_route53" {
  source = "../../components/route53_alb_weighted_alias_geo"

  app_name           = var.bidder_app_name
  coast              = var.coast
  external_http_port = var.bidder_external_http_port
  has_geo_record     = false
  geo_domain_name    = var.bidder_geo_domain_name
  geo_record_region  = var.bidder_geo_record_region
  name               = var.rtba11_external_dns_name
  region_prefix      = var.rtba11_region_prefix
  zone_name          = var.esm1_zone_name

  alb_weight   = var.rtba11_alb_weight
  alb_dns_name = module.bidder_x11_alb.alb_dns_name
  alb_zone_id  = module.bidder_x11_alb.alb_zone_id

  providers = {
    aws.east = aws.east
  }
}

module "bidder_x12_alb" {
  source = "../../components/alb"

  tag_environment   = var.tag_environment
  app_name          = var.bidder_app_name
  alb_domain        = var.elb_domain
  internal_port     = var.bidder_internal_http_port
  lb_name           = "rtb-bidder-x12-alb"
  target_protocol   = "HTTP"
  security_group_id = module.security_group.bidder_elb_http_access_sg_id

  instance_target_list = module.bidder_instances.app_instance_ids

  vpc_id = local.vpc_id

  public_subnet_names = var.elb_public_subnet_names

  enable_http  = true
  http_port    = 8080
  enable_https = true
  https_port   = 8443

  alb_healthy_threshold           = var.bidder_health_check_healthy_threshold
  alb_unhealthy_threshold         = var.bidder_health_check_unhealthy_threshold
  alb_health_timeout              = var.bidder_health_check_timeout
  alb_healthcheck_interval        = var.bidder_health_check_interval
  alb_healthcheck_target_path     = "/?ESM_HEALTH_CHECK=true"
  alb_healthcheck_target_protocol = "HTTP"
  alb_monitoring_tag              = var.bidder_alb_monitoring_tag
  workload_id                     = lookup(var.workload_mapping, var.bidder_app_name, "")
  dynamic_port                    = true
  //  ssl_cert_arn                    = "${data.aws_acm_certificate.public_cert.arn}"
  ssl_cert_arn = var.esm_cert_2021_arn
  ssl_policy   = "ELBSecurityPolicy-FS-1-2-2019-08"
}

module "bidder_alb_x12_route53" {
  source = "../../components/route53_alb_weighted_alias_geo"

  app_name           = var.bidder_app_name
  coast              = var.coast
  external_http_port = var.bidder_external_http_port
  has_geo_record     = false
  geo_domain_name    = var.bidder_geo_domain_name
  geo_record_region  = var.bidder_geo_record_region
  name               = var.rtba12_external_dns_name
  region_prefix      = var.rtba12_region_prefix
  zone_name          = var.esm1_zone_name

  alb_weight   = var.rtba12_alb_weight
  alb_dns_name = module.bidder_x12_alb.alb_dns_name
  alb_zone_id  = module.bidder_x12_alb.alb_zone_id

  providers = {
    aws.east = aws.east
  }
}

module "bidder_elb_x11" {
  source                           = "../../components/elb"
  tag_environment                  = var.tag_environment
  public_subnet_names              = var.elb_public_subnet_names
  elb_http_access_sg_id            = module.security_group.bidder_elb_http_access_sg_id
  domain                           = var.elb_domain
  internal_http_port               = var.bidder_internal_http_port
  external_http_port               = var.bidder_external_http_port
  https_port                       = var.bidder_https_port
  app_name                         = "${var.bidder_app_name}-x11"
  health_check_target              = var.bidder_health_check_target
  health_check_healthy_threshold   = var.bidder_health_check_healthy_threshold
  health_check_interval            = var.bidder_health_check_interval
  health_check_timeout             = var.bidder_health_check_timeout
  health_check_unhealthy_threshold = var.bidder_health_check_unhealthy_threshold
  instance_ids                     = module.bidder_instances.app_instance_ids
  prevent_destroy                  = var.bidder_elb_prevent_destroy
  balanced_application             = "rtb-bidder"
  access_logs_bucket               = var.access_logs_bucket
  enable_access_logs               = var.enable_access_logs
  cert_arn                         = var.esm_cert_2021_arn
  workload_id                      = lookup(var.workload_mapping, var.bidder_app_name, "")
}

module "bidder_elb_x12" {
  source                           = "../../components/elb"
  tag_environment                  = var.tag_environment
  public_subnet_names              = var.elb_public_subnet_names
  elb_http_access_sg_id            = module.security_group.bidder_elb_http_access_sg_id
  domain                           = var.elb_domain
  internal_http_port               = var.bidder_internal_http_port
  external_http_port               = var.bidder_external_http_port
  https_port                       = var.bidder_https_port
  app_name                         = "${var.bidder_app_name}-x12"
  health_check_target              = var.bidder_health_check_target
  health_check_healthy_threshold   = var.bidder_health_check_healthy_threshold
  health_check_interval            = var.bidder_health_check_interval
  health_check_timeout             = var.bidder_health_check_timeout
  health_check_unhealthy_threshold = var.bidder_health_check_unhealthy_threshold
  instance_ids                     = module.bidder_instances.app_instance_ids
  prevent_destroy                  = var.bidder_elb_prevent_destroy
  balanced_application             = "rtb-bidder"
  access_logs_bucket               = var.access_logs_bucket
  enable_access_logs               = var.enable_access_logs
  workload_id                      = lookup(var.workload_mapping, var.bidder_app_name, "")
  cert_arn                         = var.esm_cert_2021_arn
}
module "bidder_rtbx01_lb_route53" {
  source             = "../../components/route53_elb_weighted_alias_geo"
  elb_weight         = var.bidder_elb_weight
  name               = var.rtbx01_external_dns_name
  elb_dns_name       = module.bidder_elb_x01.dns_name
  zone_name          = var.esm1_zone_name
  elb_zone_id        = module.bidder_elb_x01.zone_id
  region_prefix      = var.rtbx01_region_prefix
  geo_domain_name    = var.bidder_geo_domain_name
  coast              = var.coast
  geo_record_region  = var.bidder_geo_record_region
  app_name           = "bidder"
  has_geo_record     = false
  external_http_port = var.bidder_external_http_port

  providers = {
    aws.east = aws.east
  }
}

module "bidder_route53" {
  source            = "../../components/route53"
  route53_zone_id   = data.aws_route53_zone.regional_rtb_vpc_zone.id
  route53_zone_name = data.aws_route53_zone.regional_rtb_vpc_zone.name
  records           = join(",", module.bidder_instances.app_private_ip_addresses)
  record_type       = "A"
  num_instances     = var.num_bidder_instances
  hostname_prefix   = var.bidder_app_name
  prevent_destroy   = var.bidder_route53_prevent_destroy
}

module "bidder_codedeploy" {
  source                      = "../../components/codedeploy"
  minimum_healthy_hosts_type  = var.bidder_minimum_healthy_hosts_type
  minimum_healthy_hosts_value = var.bidder_minimum_healthy_hosts_value
  single_canary               = var.bidder_single_canary
  multi_canary                = var.bidder_multi_canary
  static_group                = var.bidder_static_group
  application                 = var.bidder_app_name
  trigger_name                = var.bidder_trigger_name
  auto_rollback_enabled       = var.bidder_auto_rollback_enabled
  auto_rollback_events        = var.bidder_auto_rollback_events
  trigger_events              = var.bidder_trigger_events
  trigger_target_arn          = module.notifications_sns.sns_topic_arn
  service_role_arn            = data.terraform_remote_state.alks.outputs.codedeploy_role_arn
  instance_trigger_target_arn = module.rtb_deployment_notifications.sns_topic_arn
  tag_environment             = var.tag_environment
  region                      = var.region
}

// CONFIG-CACHE

module "configcache_a_instances" {
  source                     = "../../components/ec2"
  ssh_key_name               = var.ssh_key_name_sote
  route53_zone_name          = var.route53_zone_name
  tag_environment            = var.tag_environment
  app_security_group_id      = module.security_group.configcache_sg_id
  app_instance_type          = var.graviton_configcache_instance_type
  num_app_instances          = var.a_group_up ? var.num_configcache_instances : 0
  app_hostname_prefix        = var.configcache_a_group_hostname_prefix
  app_name                   = var.configcache_app_name
  prevent_destroy            = var.configcache_a_group_prevent_destroy
  iam_role                   = var.configcache_role
  enable_enhanced_monitoring = var.config_cache_enable_enhanced_monitoring

  region             = var.region
  ami_id             = local.configcache_graviton_amis[var.region]
  private_subnet_ids = [local.private_subnet_ids[0]]
  subnet_az          = local.private_subnet_azs
  vpc_id             = local.vpc_id
  workload_id        = lookup(var.workload_mapping, var.configcache_app_name, "")
  architecture       = "aarch64"
  coxauto_scan_reboot_tag_key = var.coxauto_scan_reboot_tag_key
}

module "configcache_b_instances" {
  source                     = "../../components/ec2"
  ssh_key_name               = var.ssh_key_name_sote
  route53_zone_name          = var.route53_zone_name
  tag_environment            = var.tag_environment
  app_security_group_id      = module.security_group.configcache_sg_id
  app_instance_type          = var.graviton_configcache_instance_type
  num_app_instances          = var.b_group_up ? var.num_configcache_instances : 0
  app_hostname_prefix        = var.configcache_b_group_hostname_prefix
  app_name                   = var.configcache_app_name
  prevent_destroy            = var.configcache_b_group_prevent_destroy
  iam_role                   = var.configcache_role
  enable_enhanced_monitoring = var.config_cache_enable_enhanced_monitoring

  region             = var.region
  ami_id             = local.configcache_graviton_amis[var.region]
  private_subnet_ids = [local.private_subnet_ids[1]]
  subnet_az          = local.private_subnet_azs
  vpc_id             = local.vpc_id
  workload_id        = lookup(var.workload_mapping, var.configcache_app_name, "")
  architecture       = "aarch64"
  coxauto_scan_reboot_tag_key = var.coxauto_scan_reboot_tag_key
}

module "configcache_codedeploy" {
  source                      = "../../components/codedeploy"
  minimum_healthy_hosts_type  = var.configcache_minimum_healthy_hosts_type
  minimum_healthy_hosts_value = var.configcache_minimum_healthy_hosts_value
  single_canary               = var.configcache_single_canary
  multi_canary                = var.configcache_multi_canary
  application                 = var.configcache_app_name
  trigger_name                = var.configcache_trigger_name
  auto_rollback_enabled       = var.configcache_auto_rollback_enabled
  auto_rollback_events        = var.configcache_auto_rollback_events
  trigger_events              = var.configcache_trigger_events
  trigger_target_arn          = module.notifications_sns.sns_topic_arn
  service_role_arn            = data.terraform_remote_state.alks.outputs.codedeploy_role_arn
  instance_trigger_target_arn = module.rtb_deployment_notifications.sns_topic_arn
  tag_environment             = var.tag_environment
  region                      = var.region
}

module "configcache_association" {
  source               = "../../components/ssm_association"
  association_name     = "${var.configcache_app_name}_app_ansible"
  ssm_document_name    = module.ssm_document_app_ansible_with_ansible.name
  association_schedule = ""

  association_parameters = {
    check       = "False"
    extravars   = "SSM=True application=${var.configcache_app_name} codedeploy_agent=true java_live_version=java17"
    playbookurl = "s3://${var.devops_bucket_name}/${var.app_ansible_multiarch_amzlinux_key}"
  }

  association_target_key    = "tag:application"
  association_target_values = [var.configcache_app_name]
}

module "configcache_a_group_route53" {
  source            = "../../components/route53"
  route53_zone_id   = data.aws_route53_zone.regional_rtb_vpc_zone.id
  route53_zone_name = data.aws_route53_zone.regional_rtb_vpc_zone.name
  num_instances     = var.a_group_up ? var.num_configcache_instances : 0
  records           = join(",", module.configcache_a_instances.app_private_ip_addresses)
  record_type       = "A"
  hostname_prefix   = var.configcache_a_group_hostname_prefix
  prevent_destroy   = var.configcache_a_group_route53_prevent_destroy
}

module "configcache_b_group_route53" {
  source            = "../../components/route53"
  route53_zone_id   = data.aws_route53_zone.regional_rtb_vpc_zone.id
  route53_zone_name = data.aws_route53_zone.regional_rtb_vpc_zone.name
  num_instances     = var.b_group_up ? var.num_configcache_instances : 0
  records           = join(",", module.configcache_b_instances.app_private_ip_addresses)
  record_type       = "A"
  hostname_prefix   = var.configcache_b_group_hostname_prefix
  prevent_destroy   = var.configcache_b_group_route53_prevent_destroy
}

/*
* module.west.module.configcache_live_route53.var.private_ip_addresses: At column 3, line 1: conditional operator cannot be used with list values in:
${var.configcache_active_group == "A" ? module.configcache_a_instances.app_private_ip_addresses : module.configcache_b_instances.app_private_ip_addresses}
*/
module "configcache_live_route53" {
  source            = "../../components/route53"
  route53_zone_id   = data.aws_route53_zone.regional_rtb_vpc_zone.id
  route53_zone_name = data.aws_route53_zone.regional_rtb_vpc_zone.name
  num_instances     = var.num_configcache_instances
  records           = var.configcache_active_group == "A" ? join(",", module.configcache_a_instances.app_private_ip_addresses) : join(",", module.configcache_b_instances.app_private_ip_addresses)
  record_type       = "A"
  hostname_prefix   = var.configcache_generic_prefix
  prevent_destroy   = var.configcache_active_group == "A" ? var.configcache_a_group_route53_prevent_destroy : var.configcache_b_group_route53_prevent_destroy
  hostname_suffix   = "-vip"
}

module "cloudwatch_dashboards" {
  source = "../../components/cloudwatch_dashboard"
  region = var.region
}

module "datadog_instances" {
  source                     = "../../components/ec2"
  ssh_key_name               = var.datadog_ssh_key_name
  route53_zone_name          = var.route53_zone_name
  tag_environment            = var.tag_environment
  app_security_group_id      = module.security_group.datadog_sg_id
  app_instance_type          = var.datadog_instance_type
  num_app_instances          = var.num_datadog_instances
  app_hostname_prefix        = var.datadog_app_name
  app_name                   = var.datadog_app_name
  prevent_destroy            = var.datadog_instance_prevent_destroy
  iam_role                   = var.datadog_role
  enable_enhanced_monitoring = var.datadog_enable_enhanced_monitoring

  region             = var.region
  ami_id             = data.aws_ami.standard_rtb_app_ami.id
  private_subnet_ids = local.private_subnet_ids
  subnet_az          = local.private_subnet_azs
  vpc_id             = local.vpc_id
  workload_id        = lookup(var.workload_mapping, "rtb-common", "")
  coxauto_scan_reboot_tag_key = var.coxauto_scan_reboot_tag_key
}

module "datadog_route53" {
  source            = "../../components/route53"
  route53_zone_id   = data.aws_route53_zone.regional_rtb_vpc_zone.id
  route53_zone_name = data.aws_route53_zone.regional_rtb_vpc_zone.name
  hostname_prefix   = var.datadog_app_name
  records           = join(",", module.datadog_instances.app_private_ip_addresses)

  //  records           = "${module.datadog_asg.network_interface_private_ip_addresses}"
  record_type     = "A"
  num_instances   = var.num_datadog_instances
  prevent_destroy = var.datadog_route53_prevent_destroy
}

module "datadog_association" {
  source               = "../../components/ssm_association"
  association_schedule = "rate(30 minutes)"

  association_parameters = {
    check       = "False"
    extravars   = "SSM=True application=${var.datadog_app_name}"
    playbookurl = "s3://${var.devops_bucket_name}/${var.datadog_ansible_key}"
  }

  association_name  = "${var.datadog_app_name}_app_ansible"
  ssm_document_name = var.datadog_document_name

  association_target_key    = "tag:application"
  association_target_values = [var.datadog_app_name]
}

// sns
module "rtb_sns_to_slack_subscription" {
  source                    = "../../components/sns_subscription"
  sns_subscription_endpoint = var.rtb_sns_to_slack_subscription_endpoint
  sns_subscription_protocol = var.rtb_sns_to_slack_subscription_protocol
  sns_topic_name            = module.notifications_sns.sns_topic_arn
  auto_confirms             = true
  enable                    = var.rds_sns_to_slack_enable
  region                    = var.region
}

module "rtb_aws_alerts_daytime_pd_subscription" {
  source                    = "../../components/sns_subscription"
  sns_subscription_endpoint = var.daytime_pd_subscription_endpoint
  sns_subscription_protocol = var.daytime_pd_subscription_protocol
  sns_topic_name            = module.daytime_sns.sns_topic_arn
  auto_confirms             = true
  enable                    = var.daytime_subscription_enable
  region                    = var.region
}

module "rtb_aws_alerts_critical_pd_subscription" {
  source                    = "../../components/sns_subscription"
  sns_subscription_endpoint = var.critical_pd_subscription_endpoint
  sns_subscription_protocol = var.critical_pd_subscription_protocol
  sns_topic_name            = module.critical_sns.sns_topic_arn
  auto_confirms             = true
  enable                    = var.critical_subscription_enable
  region                    = var.region
}

module "raw_ads_requests_stream" {
  source = "../../components/kinesis"

  retention_period_hours = var.raw_ads_retention_hours
  stream_name            = "raw_ads_requests"
  shard_count            = var.raw_ads_num_shards
  enabled_shard_metrics  = var.raw_ads_pix_shard_metrics
  lag_alerting_time      = var.ads_kinesis_lag_alerting_time
  region                 = var.region
  tag_environment        = var.tag_environment
  workload_id            = lookup(var.workload_mapping, var.ads_app_name, "")
}

module "raw_pix_requests_stream" {
  source = "../../components/kinesis"

  retention_period_hours = var.raw_pix_retention_hours
  stream_name            = "raw_pix_requests"
  shard_count            = var.raw_pix_num_shards
  enabled_shard_metrics  = var.raw_ads_pix_shard_metrics
  lag_alerting_time      = var.pix_kinesis_lag_alerting_time
  region                 = var.region
  tag_environment        = var.tag_environment
  workload_id            = lookup(var.workload_mapping, var.pix_app_name, "")
}

module "rtb_deployment_notifications" {
  source           = "../../components/sns"
  sns_topic_name   = var.rtb_deployment_notifications_topic_name
  sns_display_name = var.rtb_deployment_notifications_display_name
  region           = var.region
  tag_environment  = var.tag_environment
  workload_id      = lookup(var.workload_mapping, "rtb-common", "")
}

data "aws_lambda_function" "rtb_deployment_notifier" {
  function_name = var.rtb_deployment_notifier_name
}

module "rtb_deployment_notifications_subscription" {
  source                    = "../../components/sns_subscription"
  sns_subscription_endpoint = data.aws_lambda_function.rtb_deployment_notifier.arn
  sns_subscription_protocol = var.rtb_deployment_notifications_subscription_protocol
  enable                    = var.rtb_deployment_notifications_enable
  sns_topic_name            = module.rtb_deployment_notifications.sns_topic_arn
  auto_confirms             = true
  region                    = var.region
}

resource "aws_s3_bucket" "hollow_bucket" {
  bucket = "${var.alks_account}-hollow-${var.region}"

  lifecycle_rule {
    enabled = true
    prefix  = "AdsTxt/"

    expiration {
      days = 30
    }
  }

  lifecycle_rule {
    enabled = true
    prefix  = "AdsTxtFailures/"

    expiration {
      days = 30
    }
  }

  lifecycle_rule {
    enabled = true
    prefix  = "AdsTxtFailuresTest/"

    expiration {
      days = 30
    }
  }

  lifecycle_rule {
    enabled = true
    prefix  = "AdsTxtTest/"

    expiration {
      days = 30
    }
  }

  versioning {
    enabled = true
  }

  tags = {
    name                  = "${var.alks_account}-hollow-${var.region}"
    platform              = "ddc-advertising"
    product               = "rtb"
    application           = "rtb-hollow-producer"
    application-component = "adstxt-producer"
    environment           = var.tag_environment
    slackContact          = "+rtb-issues"
    "coxauto:ci-id"       = lookup(var.workload_mapping, var.bidder_app_name, "")
    Name                  = "${var.alks_account}-hollow-${var.region}"
  }
}

module "config_services_ecs_cluster" {
  source                     = "../../components/ecs_cluster"
  cluster_name               = var.config_services_ecs_cluster_name
  cluster_instance_role_name = var.config_services_cluster_instance_role_name
  cluster_instance_type      = var.config_services_cluster_instance_type
  cluster_ami_id             = local.new_graviton_amis[var.region]
  region                     = var.region
  ssh_key_name               = var.ssh_key_name_sote
  cluster_size               = var.config_services_ecs_cluster_size
  vpc_id                     = local.vpc_id
  cluster_subnet_ids         = slice(local.private_subnet_ids, 0, length(var.private_subnets)) // ugh just use all subnets in future
  cluster_subnet_az          = local.private_subnet_azs
  cluster_security_groups    = [module.security_group.config_services_ecs_security_group_id]
  task_role_arn              = var.dd_agent_task_role
  execution_role_arn         = var.dd_agent_task_role
  dd_api_key                 = var.dd_api_key
  dd_docker_image            = "public.ecr.aws/datadog/agent:7.52.1"
  sumologic_driver            = "sumologic/docker-logging-driver:1.0.6-aarch64"
  alks_account_id            = var.alks_account_id
  tag_environment            = var.tag_environment
  workload_id                = lookup(var.workload_mapping, var.config_services_shortname, "")
  coxauto_scan_reboot_tag_key = var.coxauto_scan_reboot_tag_key
}

module "rtb_config_services_prod" {
  source                              = "../../components/snowflakes/config_services_ecs_single"
  config_services_ecs_memory          = var.config_services_container_memory
  config_services_desired_containers  = var.config_services_desired_containers
  config_services_container_port      = var.config_services_container_port
  config_services_inactive_port       = var.config_services_inactive_port
  vpc_id                              = local.vpc_id
  region                              = var.region
  config_services_service_name_prefix = var.config_services_shortname
  alks_account_id                     = var.alks_account_id
  dd_agent_task_role                  = var.dd_agent_task_role
  ecs_task_execution_role             = var.ecs_task_execution_role
  config_services_container_role      = var.config_services_container_role
  config_services_log_group_name      = var.config_services_shortname
  alks_account                        = var.alks_account
  dd_api_key                          = var.dd_api_key
  ssh_key_name                        = var.ssh_key_name_sote
  tag_environment                     = var.tag_environment
  config_services_container_name      = var.config_services_container_name
  route53_zone_id                     = data.aws_route53_zone.rtb_zone.id
  config_services_dns_record_name     = "${var.config_services_dns_record_name}-${var.region}"
  config_services_ecr_repo_name       = var.config_services_shortname
  config_services_ecr_policy          = var.default_ecr_policy
  config_services_ecr_lifecycle_tags  = var.config_services_ecr_lifecycle_tags
  public_subnet_ids = slice(
    local.all_public_subnet_ids_ordered,
    0,
    length(var.config_services_lb_pub_subnets),
  ) // ugh just use all subnets in future
  lock_table_name                = "${var.config_services_shortname}-locks"
  ecs_cluster_name               = var.config_services_ecs_cluster_name
  ecs_cluster_id                 = module.config_services_ecs_cluster.id
  deployment_controller          = "ECS"
  codedeploy_role_arn            = var.config_services_codedeploy_role_arn
  rtb_cert_domain                = var.rtb_cert_domain
  https_alb_security_group_id    = module.security_group.config_services_alb_security_group_id
  container_deregistration_delay = "10"
  workload_id                    = lookup(var.workload_mapping, var.config_services_shortname, "")

  providers = {

    aws.west = aws.west
    aws.east = aws.east
  }
}

module "rtb_config_services_prod_beta" {
  source                              = "../../components/snowflakes/config_services_ecs_single"
  config_services_ecs_memory          = var.config_services_container_memory
  config_services_container_port      = var.config_services_container_port
  config_services_inactive_port       = var.config_services_inactive_port
  vpc_id                              = local.vpc_id
  config_services_desired_containers  = var.config_services_desired_containers
  region                              = var.region
  config_services_service_name_prefix = "${var.config_services_shortname}-beta"
  alks_account_id                     = var.alks_account_id
  dd_agent_task_role                  = var.dd_agent_task_role
  ecs_task_execution_role             = var.ecs_task_execution_role
  config_services_container_role      = var.config_services_container_role
  config_services_log_group_name      = "${var.config_services_shortname}-beta"
  alks_account                        = var.alks_account
  dd_api_key                          = var.dd_api_key
  ssh_key_name                        = var.ssh_key_name_sote
  tag_environment                     = "${var.tag_environment}-beta"
  config_services_container_name      = var.config_services_container_name
  route53_zone_id                     = data.aws_route53_zone.rtb_zone.id
  config_services_dns_record_name     = "${var.config_services_dns_record_name}-beta-${var.region}"
  config_services_ecr_repo_name       = "${var.config_services_shortname}-beta"
  config_services_ecr_policy          = var.default_ecr_policy
  config_services_ecr_lifecycle_tags  = var.config_services_ecr_lifecycle_tags
  public_subnet_ids = slice(
    local.all_public_subnet_ids_ordered,
    0,
    length(var.config_services_lb_pub_subnets),
  ) // ugh just use all subnets in future
  lock_table_name                = "${var.config_services_shortname}-locks-beta"
  ecs_cluster_id                 = module.config_services_ecs_cluster.id
  deployment_controller          = "ECS"
  codedeploy_role_arn            = var.config_services_codedeploy_role_arn
  ecs_cluster_name               = module.config_services_ecs_cluster.name
  rtb_cert_domain                = var.rtb_cert_domain
  https_alb_security_group_id    = module.security_group.config_services_alb_security_group_id
  container_deregistration_delay = "10"
  workload_id                    = lookup(var.workload_mapping, var.config_services_shortname, "")

  providers = {

    aws.west = aws.west
    aws.east = aws.east
  }
}

data "aws_secretsmanager_secret_version" "retool_postgres_user" {
  secret_id     = var.retool_secretsmanager_db_user
  version_stage = "AWSCURRENT"

  provider = aws.east
}

data "aws_secretsmanager_secret_version" "retool_postgres_password" {
  secret_id     = var.retool_secretsmanager_db_pass
  version_stage = "AWSCURRENT"

  provider = aws.east
}

data "aws_secretsmanager_secret_version" "retool_jwt" {
  secret_id     = var.retool_secretsmanager_jwt
  version_stage = "AWSCURRENT"

  provider = aws.east
}

data "aws_secretsmanager_secret_version" "retool_okta_api_key" {
  secret_id     = var.retool_secretsmanager_okta_api_key
  version_stage = "AWSCURRENT"

  provider = aws.east
}

data "aws_secretsmanager_secret_version" "retool_encryption_key" {
  secret_id     = var.retool_secretsmanager_encryption_key
  version_stage = "AWSCURRENT"

  provider = aws.east
}

data "aws_secretsmanager_secret_version" "retool_license_key" {
  secret_id     = var.retool_secretsmanager_license_key
  version_stage = "AWSCURRENT"

  provider = aws.east
}

data "aws_secretsmanager_secret_version" "retool_config_svc_cert" {
  secret_id     = var.retool_secretsmanager_config_services_cert
  version_stage = "AWSCURRENT"

  provider = aws.east
}

data "aws_secretsmanager_secret_version" "retool_config_svc_cert_private_key" {
  secret_id     = var.retool_secretsmanager_config_services_cert_private_key
  version_stage = "AWSCURRENT"

  provider = aws.east
}

data "aws_secretsmanager_secret_version" "retool_config_svc_cert_chain" {
  secret_id     = var.retool_secretsmanager_config_services_cert_chain
  version_stage = "AWSCURRENT"

  provider = aws.east
}

data "aws_secretsmanager_secret_version" "retool_secretsmanager_program_manager_api_key" {
  secret_id     = var.retool_secretsmanager_program_manager_api_key
  version_stage = "AWSCURRENT"

  provider = aws.east
}

data "aws_secretsmanager_secret_version" "retool_secretsmanager_program_manager_api_endpoint" {
  secret_id     = var.retool_secretsmanager_program_manager_api_endpoint
  version_stage = "AWSCURRENT"

  provider = aws.east
}

data "aws_secretsmanager_secret_version" "retool_secretsmanager_program_manager_api_key_staging" {
  secret_id     = var.retool_secretsmanager_program_manager_api_key_staging
  version_stage = "AWSCURRENT"

  provider = aws.east
}
data "aws_secretsmanager_secret_version" "retool_secretsmanager_template_manager_api_key" {
  secret_id     = var.retool_secretsmanager_template_manager_api_key
  version_stage = "AWSCURRENT"

  provider = aws.east
}

data "aws_secretsmanager_secret_version" "retool_secretsmanager_template_manager_api_key_staging" {
  secret_id     = var.retool_secretsmanager_template_manager_api_key_staging
  version_stage = "AWSCURRENT"

  provider = aws.east
}

data "aws_secretsmanager_secret_version" "retool_secretsmanager_change_tracker_api_key" {
  secret_id     = var.retool_secretsmanager_change_tracker_api_key
  version_stage = "AWSCURRENT"

  provider = aws.east
}

data "aws_secretsmanager_secret_version" "retool_secretsmanager_change_tracker_api_key_staging" {
  secret_id     = var.retool_secretsmanager_change_tracker_api_key_staging
  version_stage = "AWSCURRENT"

  provider = aws.east
}

data "aws_secretsmanager_secret_version" "retool_secretsmanager_adv_product_services_key" {
  secret_id     = var.retool_secretsmanager_adv_product_services_key
  version_stage = "AWSCURRENT"

  provider = aws.east
}

data "aws_secretsmanager_secret_version" "retool_secretsmanager_adv_product_services_key_staging" {
  secret_id     = var.retool_secretsmanager_adv_product_services_key_staging
  version_stage = "AWSCURRENT"

  provider = aws.east
}

data "aws_secretsmanager_secret_version" "retool_secretsmanager_tailored_video_services_key" {
  secret_id     = var.retool_secretsmanager_tailored_video_services_key
  version_stage = "AWSCURRENT"

  provider = aws.east
}

data "aws_secretsmanager_secret_version" "retool_secretsmanager_tailored_video_services_key_staging" {
  secret_id     = var.retool_secretsmanager_tailored_video_services_key_staging
  version_stage = "AWSCURRENT"

  provider = aws.east
}

data "aws_secretsmanager_secret_version" "retool_account_metadata_token" {
  secret_id     = "/retool/accountMetadataApi"
  version_stage = "AWSCURRENT"

  provider = aws.east
}

data "aws_secretsmanager_secret_version" "ddc_account_data_distributor_password" {
  secret_id     = "/retool/add-api-key"
  version_stage = "AWSCURRENT"

  provider = aws.east
}

data "aws_secretsmanager_secret_version" "retool_github_app_private_key" {
  secret_id     = "/retool/github-app-secrets/private-key"
  version_stage = "AWSCURRENT"

  provider = aws.east
}

module "retool_repo" {
  source             = "../../components/ecr"
  repo_name          = "${var.retool_app_name}-repo"
  ecr_policy         = var.default_ecr_policy
  lifecycle_tag_list = ["latest"]
  workload_id        = lookup(var.workload_mapping, var.retool_app_name, "")
}

module "retool_proxy_repo" {
  source             = "../../components/ecr"
  repo_name          = "${var.retool_app_name}-proxy-repo"
  ecr_policy         = var.default_ecr_policy
  lifecycle_tag_list = ["latest"]
  workload_id        = lookup(var.workload_mapping, var.retool_app_name, "")
}

module "retool_fargate_ecs_cluster" {
  source                     = "../../components/ecs_cluster_retool"
  cluster_name               = "fargate-${var.retool_cluster_name}"
  tag_environment            = var.tag_environment
  workload_id                = lookup(var.workload_mapping, var.retool_app_name, "")
}

module "retool_fargate_public_alb" {
  source                          = "../../components/alb"
  alb_domain                      = var.rtb_cert_domain
  alb_health_timeout              = var.retool_healthcheck_timeout
  alb_healthcheck_interval        = var.retool_healthcheck_interval
  alb_healthcheck_target_path     = var.retool_healthcheck_path
  alb_healthcheck_target_protocol = var.retool_healthcheck_protocol
  alb_healthy_threshold           = var.retool_healthy_threshold
  alb_monitoring_tag              = var.retool_monitoring_tag
  alb_unhealthy_threshold         = var.retool_unhealthy_threshold
  app_name                        = var.retool_app_name
  internal_port                   = var.retool_internal_port
  public_subnet_names             = var.elb_public_subnet_names
  tag_environment                 = var.tag_environment
  target_protocol                 = var.retool_protocol
  security_group_id               = module.security_group.load_balancer_public_https_access_sg_id
  lb_name                         = "${var.retool_app_name}-fargate-public-lb"
  vpc_id                          = local.vpc_id
  enable_http                     = false
  enable_https                    = true
  internal                        = false
  dynamic_port                    = true
  deregistration_delay            = 30
  ssl_cert_arn                    = data.aws_acm_certificate.rtb_public_cert.arn
  workload_id                     = lookup(var.workload_mapping, var.retool_app_name, "")
  target_type                     = "ip"
}

data "aws_ssm_parameter" "sumo_url" {
  name = "sumo-http-endpoint"
}

data "aws_secretsmanager_secret_version" "beta_cfg_svc_key" {
  secret_id     = "/config-services/beta/internal/secret"
  version_stage = "AWSCURRENT"
  provider      = aws.east
}

data "aws_secretsmanager_secret_version" "live_cfg_svc_key" {
  secret_id     = "/config-services/beta/internal/secret"
  version_stage = "AWSCURRENT"
  provider      = aws.east
}

data "aws_secretsmanager_secret_version" "live_cfg_svc_testing_key" {
  secret_id     = "/config-services/live/integration-testing/secret"
  version_stage = "AWSCURRENT"
  provider      = aws.east
}

locals {
  retool_task_vars = {
    account_id         = var.alks_account_id
    account_name       = var.alks_account_id
    cpu_fargate        = var.retool_fargate_task_cpu
    memory_fargate     = var.retool_fargate_task_mem
    services_scripts   = var.retool_fargate_config_services_scripts
    environment        = var.tag_environment
    service_type       = var.retool_service_type
    sumo_http_endpoint = data.aws_ssm_parameter.sumo_url.value
    container_name     = var.retool_app_name
    retool_repo_url    = replace(module.retool_repo.ecr_repo_url, "us-west-1", "us-east-1")
    region             = var.region
    postgres_user      = data.aws_secretsmanager_secret_version.retool_postgres_user.secret_string
    postgres_password  = data.aws_secretsmanager_secret_version.retool_postgres_password.secret_string
    postgres_dns       = var.retool_postgres_primary_address
    jwt_secret         = data.aws_secretsmanager_secret_version.retool_jwt.secret_string
    okta_api_key       = data.aws_secretsmanager_secret_version.retool_okta_api_key.secret_string
    encryption_key     = data.aws_secretsmanager_secret_version.retool_encryption_key.secret_string
    retool_license_key = data.aws_secretsmanager_secret_version.retool_license_key.secret_string
    secrets_region     = "us-east-1"
    proxy_repo_url = replace(
      module.retool_proxy_repo.ecr_repo_url,
      "us-west-1",
      "us-east-1",
    )
    beta_key                              = data.aws_secretsmanager_secret_version.beta_cfg_svc_key.secret_string
    live_key                              = data.aws_secretsmanager_secret_version.live_cfg_svc_key.secret_string
    live_testing_key                      = data.aws_secretsmanager_secret_version.live_cfg_svc_testing_key.secret_string
    proxy_cpu                             = var.retool_proxy_cpu
    proxy_mem                             = var.retool_proxy_mem
    athena_output_bucket                  = var.retool_athena_output_bucket
    ddc_account_metadata_token            = data.aws_secretsmanager_secret_version.retool_account_metadata_token.secret_string
    ddc_account_data_distributor_password = data.aws_secretsmanager_secret_version.ddc_account_data_distributor_password.secret_string
    program_manager_api_key               = data.aws_secretsmanager_secret_version.retool_secretsmanager_program_manager_api_key.secret_string
    program_manager_api_endpoint          = data.aws_secretsmanager_secret_version.retool_secretsmanager_program_manager_api_endpoint.secret_string
    program_manager_api_key_staging       = data.aws_secretsmanager_secret_version.retool_secretsmanager_program_manager_api_key_staging.secret_string
    template_manager_api_key              = data.aws_secretsmanager_secret_version.retool_secretsmanager_template_manager_api_key.secret_string
    template_manager_api_key_staging      = data.aws_secretsmanager_secret_version.retool_secretsmanager_template_manager_api_key_staging.secret_string
    change_tracker_api_key                = data.aws_secretsmanager_secret_version.retool_secretsmanager_change_tracker_api_key.secret_string
    change_tracker_api_key_staging        = data.aws_secretsmanager_secret_version.retool_secretsmanager_change_tracker_api_key_staging.secret_string
    adv_product_services_key              = jsondecode(data.aws_secretsmanager_secret_version.retool_secretsmanager_adv_product_services_key.secret_string)["basic_auth"]
    adv_product_services_key_staging      = jsondecode(data.aws_secretsmanager_secret_version.retool_secretsmanager_adv_product_services_key_staging.secret_string)["basic_auth"]
    tailored_video_services_client_id     = jsondecode(data.aws_secretsmanager_secret_version.retool_secretsmanager_tailored_video_services_key.secret_string)["client_id"]
    tailored_video_services_client_secret = jsondecode(data.aws_secretsmanager_secret_version.retool_secretsmanager_tailored_video_services_key.secret_string)["client_secret"]
    tailored_video_services_scope = jsondecode(data.aws_secretsmanager_secret_version.retool_secretsmanager_tailored_video_services_key.secret_string)["scope"]
    tailored_video_services_client_id_staging     = jsondecode(data.aws_secretsmanager_secret_version.retool_secretsmanager_tailored_video_services_key_staging.secret_string)["client_id"]
    tailored_video_services_client_secret_staging = jsondecode(data.aws_secretsmanager_secret_version.retool_secretsmanager_tailored_video_services_key_staging.secret_string)["client_secret"]
    tailored_video_services_scope_staging = jsondecode(data.aws_secretsmanager_secret_version.retool_secretsmanager_tailored_video_services_key_staging.secret_string)["scope"]
    github_app_private_key                = data.aws_secretsmanager_secret_version.retool_github_app_private_key.secret_string
    log_group_name                        = aws_cloudwatch_log_group.retool_log_group.name
  }
}

resource "aws_cloudwatch_log_group" "retool_log_group" {
  name = "/aws/ecs/retool"

  tags = {
    platform        = "ddc-advertising"
    product         = "rtb"
    slackContact    = "+rtb-issues"
    "coxauto:ci-id" = lookup(var.workload_mapping, var.retool_app_name, "")
    application     = var.retool_app_name
    region          = var.region
  }
}

resource "template_file" "retool_fargate_task_definition_service_type" {
  template = file(
    "${path.module}/../../components/task_definitions/retool_container_definition_with_service_type.json"
  )

  vars = local.retool_task_vars
}

resource "aws_ecs_task_definition" "retool_fargate_task_definition" {
  family                   = "${var.retool_app_name}-fargate-taskdef"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.retool_fargate_task_cpu
  memory                   = var.retool_fargate_task_mem
  container_definitions    = template_file.retool_fargate_task_definition_service_type.rendered

  execution_role_arn = var.retool_execution_role_arn
  task_role_arn      = var.retool_task_role_arn

  tags = {
    platform        = "ddc-advertising"
    product         = "rtb"
    slackContact    = "+rtb-issues"
    "coxauto:ci-id" = lookup(var.workload_mapping, var.retool_app_name, "")
    application     = var.retool_app_name
    region          = var.region
  }
}

resource "aws_ecs_service" "retool_fargate_ecs_service" {
  name          = "${var.retool_app_name}-fargate"
  desired_count = var.retool_fargate_desired_tasks

  cluster                            = module.retool_fargate_ecs_cluster.id
  task_definition                    = aws_ecs_task_definition.retool_fargate_task_definition.arn
  launch_type                        = "FARGATE"
  deployment_minimum_healthy_percent = var.retool_minimum_healthy
  network_configuration {
    security_groups = [module.security_group.retool_global_cidr_sg_id, module.security_group.fargate_ecr_access_sg_id]
    subnets         =  local.private_subnet_ids
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = module.retool_fargate_public_alb.alb_target_group_arn
    container_name   = var.retool_app_name
    container_port   = var.retool_internal_port
  }

  tags = {
    platform        = "ddc-advertising"
    product         = "rtb"
    slackContact    = "+rtb-issues"
    "coxauto:ci-id" = lookup(var.workload_mapping, var.retool_app_name, "")
    application     = var.retool_app_name
    region          = var.region
  }
}



data "aws_route53_zone" "rtb_zone" {
  name = var.config_services_zone_name
}

resource "aws_route53_record" "fargate_alb_record" {
  zone_id         = data.aws_route53_zone.rtb_zone.id
  name            = "${var.retool_app_name}-fargate-${var.coast}"
  type            = "A"
  set_identifier  = "fargate_alb"
  health_check_id = aws_route53_health_check.retool_alb_healthcheck.id

  weighted_routing_policy {
    weight = "100"
  }

  alias {
    name                   = module.retool_fargate_public_alb.alb_dns_name
    zone_id                = module.retool_fargate_public_alb.alb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_cloudwatch_metric_alarm" "retool_atg_unhealthy_alarm" {
  alarm_name          = "retool-unhealthy-instances"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "HealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  treat_missing_data  = "breaching"

  dimensions = {
    TargetGroup  = module.retool_fargate_public_alb.alb_tg_arn_suffix
    LoadBalancer = module.retool_fargate_public_alb.alb_arn_suffix
  }

  period            = "60"
  statistic         = "Average"
  threshold         = "1"
  alarm_description = "Monitors healthy instances in the TG"
}

resource "aws_cloudwatch_metric_alarm" "dynamic_click_tag_failure_alarm" {
  alarm_name          = "dynamic-click-tag-failure"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "DynamicClickTagFailureCount"
  namespace           = "CreativeLogging"

  period            = "900"
  statistic         = "Sum"
  threshold         = "1000"
  alarm_description = "Dynamic click tag generation is failing"

  # TF-UPGRADE-TODO: In Terraform v0.10 and earlier, it was sometimes necessary to
  # force an interpolation expression to be interpreted as a list by wrapping it
  # in an extra set of list brackets. That form was supported for compatibility in
  # v0.11, but is no longer supported in Terraform v0.12.
  #
  # If the expression in the following list itself returns a list, remove the
  # brackets to avoid interpretation as a list of lists. If the expression
  # returns a single list item then leave it as-is and remove this TODO comment.
  alarm_actions = [module.daytime_sns.sns_topic_arn]
  # TF-UPGRADE-TODO: In Terraform v0.10 and earlier, it was sometimes necessary to
  # force an interpolation expression to be interpreted as a list by wrapping it
  # in an extra set of list brackets. That form was supported for compatibility in
  # v0.11, but is no longer supported in Terraform v0.12.
  #
  # If the expression in the following list itself returns a list, remove the
  # brackets to avoid interpretation as a list of lists. If the expression
  # returns a single list item then leave it as-is and remove this TODO comment.
  ok_actions = [module.daytime_sns.sns_topic_arn]
}

resource "aws_cloudwatch_metric_alarm" "vehicle_image_load_failure_alarm" {
  alarm_name          = "vehicle-image-load-failure"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "VehicleImageLoadFailureCount"
  namespace           = "CreativeLogging"

  period            = "900"
  statistic         = "Sum"
  threshold         = "10000"
  alarm_description = "Failing to load vehicle images"

  # TF-UPGRADE-TODO: In Terraform v0.10 and earlier, it was sometimes necessary to
  # force an interpolation expression to be interpreted as a list by wrapping it
  # in an extra set of list brackets. That form was supported for compatibility in
  # v0.11, but is no longer supported in Terraform v0.12.
  #
  # If the expression in the following list itself returns a list, remove the
  # brackets to avoid interpretation as a list of lists. If the expression
  # returns a single list item then leave it as-is and remove this TODO comment.
  alarm_actions = [module.daytime_sns.sns_topic_arn]
  # TF-UPGRADE-TODO: In Terraform v0.10 and earlier, it was sometimes necessary to
  # force an interpolation expression to be interpreted as a list by wrapping it
  # in an extra set of list brackets. That form was supported for compatibility in
  # v0.11, but is no longer supported in Terraform v0.12.
  #
  # If the expression in the following list itself returns a list, remove the
  # brackets to avoid interpretation as a list of lists. If the expression
  # returns a single list item then leave it as-is and remove this TODO comment.
  ok_actions = [module.daytime_sns.sns_topic_arn]
}

resource "aws_cloudwatch_metric_alarm" "vehicle_payload_load_failure_alarm" {
  alarm_name          = "vehicle-payload-load-failure"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "VehiclePayloadLoadFailureCount"
  namespace           = "CreativeLogging"

  period            = "900"
  statistic         = "Sum"
  threshold         = "1000"
  alarm_description = "Failing to load vehicle payloads"

  # TF-UPGRADE-TODO: In Terraform v0.10 and earlier, it was sometimes necessary to
  # force an interpolation expression to be interpreted as a list by wrapping it
  # in an extra set of list brackets. That form was supported for compatibility in
  # v0.11, but is no longer supported in Terraform v0.12.
  #
  # If the expression in the following list itself returns a list, remove the
  # brackets to avoid interpretation as a list of lists. If the expression
  # returns a single list item then leave it as-is and remove this TODO comment.
  alarm_actions = [module.daytime_sns.sns_topic_arn]
  # TF-UPGRADE-TODO: In Terraform v0.10 and earlier, it was sometimes necessary to
  # force an interpolation expression to be interpreted as a list by wrapping it
  # in an extra set of list brackets. That form was supported for compatibility in
  # v0.11, but is no longer supported in Terraform v0.12.
  #
  # If the expression in the following list itself returns a list, remove the
  # brackets to avoid interpretation as a list of lists. If the expression
  # returns a single list item then leave it as-is and remove this TODO comment.
  ok_actions = [module.daytime_sns.sns_topic_arn]
}

resource "aws_route53_health_check" "retool_alb_healthcheck" {
  type                            = "CLOUDWATCH_METRIC"
  cloudwatch_alarm_name           = aws_cloudwatch_metric_alarm.retool_atg_unhealthy_alarm.alarm_name
  cloudwatch_alarm_region         = var.region
  insufficient_data_health_status = "Unhealthy"
}

resource "aws_route53_record" "retool_alias_geo" {
  zone_id         = data.aws_route53_zone.rtb_zone.id
  name            = var.retool_geo_name
  type            = "A"
  set_identifier  = "${var.retool_app_name}-${var.coast}-geo"
  health_check_id = aws_route53_health_check.retool_alb_healthcheck.id

  latency_routing_policy {
    region = var.region
  }

  alias {
    name                   = var.retool_regional_name
    zone_id                = data.aws_route53_zone.rtb_zone.id
    evaluate_target_health = true
  }
}

#module "firehose-impression-enrichments-direct-put" {
#  source                   = "../../components/kinesis/firehose"
#  stream_name              = var.impression_enrichments_stream_name
#  firehose_role_arn        = var.impression_enrichments_firehose_role_arn
#  tag-environment          = var.impression_enrichments_firehose_tag_environment
#  firehose_bucket_arn      = var.impression_enrichments_firehose_bucket_arn
#  firehose_buffer_size     = var.impression_enrichments_firehose_buffer_size
#  firehose_buffer_interval = var.impression_enrichments_firehose_buffer_interval
#  firehose_bucket_prefix   = var.impression_enrichments_firehose_bucket_prefix
#  region                   = var.region
#}

module "firehose_live_raw_bids_requests" {
  source                         = "../../components/kinesis/firehose-extended"
  stream_name                    = "live-raw-bid-requests"
  firehose_bucket_arn            = var.live_raw_bids_bucket_arn
  firehose_bucket_prefix         = ""
  firehose_role_arn              = var.live_raw_bids_firehose_role_arn
  firehose_buffer_size           = 128
  firehose_buffer_interval       = 60
  firehose_s3_compression_format = "GZIP"
  region                         = var.region
  tag-environment                = var.live_raw_bids_firehose_tag_environment
}

module "firehose_exchange_loss_notifications" {
  source                         = "../../components/kinesis/firehose-extended"
  stream_name                    = "exchange-loss-notifications"
  firehose_bucket_arn            = "arn:aws:s3:::${var.alks_account}-rtb-raw-incoming"
  firehose_bucket_prefix         = "loss-notifications/result=success/loss-notifications/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/"
  error_output_prefix            = "loss-notifications/result=!{firehose:error-output-type}/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/"
  firehose_role_arn              = var.exchange_loss_notification_firehose_role_arn
  firehose_buffer_size           = 1
  firehose_buffer_interval       = 60
  firehose_s3_compression_format = "GZIP"
  region                         = var.region
  tag-environment                = var.tag_environment
}

data "aws_secretsmanager_secret" "fluency_webhook_api_token" {
  name = var.fluency_webhook_secret_api_token
}

data "aws_secretsmanager_secret_version" "fluency_webhook_secret_api_token" {
  secret_id = data.aws_secretsmanager_secret.fluency_webhook_api_token.id
}

data "aws_secretsmanager_secret" "fluency_webhook_client_id" {
  name = var.fluency_webhook_secret_client_id
}

data "aws_secretsmanager_secret_version" "fluency_webhook_secret_client_id" {
  secret_id = data.aws_secretsmanager_secret.fluency_webhook_client_id.id
}

module "eventbridge" {
  source                        = "../../components/eventbridge"
  create                        = true
  create_bus                    = true
  create_rules                  = true
  create_connections            = true
  create_api_destinations       = true
  attach_api_destination_policy = true
  create_role                   = true
  region                        = var.region

  bus_name = var.fluency_eventbridge_name

  rules = {
    fluency = {
      description   = "Send events to Fluency"
      event_pattern = jsonencode({ "source" : ["RTB Product Feed Processor"] })
      enabled       = true
    }
  }

  targets = {
    fluency = [
      {
        name            = "fluency-webhook"
        destination     = "fluency"
        attach_role_arn = true
      }
      //      {
      //        name = "fluency-webhook-logs"
      //        destination = "logs"
      //        attach_role_arn = true
      //      }
    ]
  }

  connections = {
    fluency = {
      authorization_type = "API_KEY"
      auth_parameters = {
        api_key = {
          key   = "token"
          value = data.aws_secretsmanager_secret_version.fluency_webhook_secret_api_token.secret_string
        }

        invocation_http_parameters = {
          header = [
            {
              key   = "client"
              value = nonsensitive(data.aws_secretsmanager_secret_version.fluency_webhook_secret_client_id.secret_string)
            }
          ]
        }
      }
    }
  }

  api_destinations = {
    fluency = {
      name                             = "fluency-webhook-endpoint"
      description                      = "Fluency given endpoint for events"
      invocation_endpoint              = var.fluency_invocation_target
      http_method                      = var.fluency_invocation_method
      invocation_rate_limit_per_second = var.fluency_invocation_ratelimit
    }
  }

  tags = {
    Name                  = var.fluency_eventbridge_name
    platform              = "ddc-advertising"
    product               = "rtb"
    application           = "rtb-fluency-eventbridge"
    application-component = "eventbridge"
    environment           = var.tag_environment
    slackContact          = "+rtb-issues"
  }

  workload_id                         = lookup(var.workload_mapping, "rtb-common", "")
  feed_processor_eventing_schema      = var.feed_processor_eventing_schema
  feed_processor_eventing_schema_name = var.feed_processor_eventing_schema_name
  feed_processor_registry_name        = var.feed_processor_registry_name
}

resource "aws_dynamodb_table" "rtb_cfg_svc_internal_pricing_model" {
  provider = aws

  name           = "campaign-pricing-model"
  hash_key       = "campaignId"
  read_capacity  = 20
  write_capacity = 20

  attribute {
    name = "campaignId"
    type = "S"
  }
  attribute {
    name = "pricingModel"
    type = "S"
  }

  global_secondary_index {
    name            = "pricingModelIndex"
    hash_key        = "pricingModel"
    read_capacity   = 20
    write_capacity  = 20
    projection_type = "ALL"
  }

  tags = {
    platform              = "ddc-advertising"
    product               = "rtb"
    application           = "rtb-locks"
    slackContact          = "+rtb-issues"
    application-component = "dynamodb"
    environment           = var.tag_environment
    "coxauto:ci-id"       = lookup(var.workload_mapping, var.config_services_shortname, "")
  }
}


resource "aws_dynamodb_table" "beta_rtb_cfg_svc_internal_pricing_model" {
  provider = aws

  name           = "beta-campaign-pricing-model"
  hash_key       = "campaignId"
  read_capacity  = 20
  write_capacity = 20

  attribute {
    name = "campaignId"
    type = "S"
  }
  attribute {
    name = "pricingModel"
    type = "S"
  }

  // beta pricing model table will let pricing models expire so local tests don't clog it
  ttl {
    attribute_name = "expirationTime"
    enabled        = true
  }

  global_secondary_index {
    name            = "pricingModelIndex"
    hash_key        = "pricingModel"
    read_capacity   = 20
    write_capacity  = 20
    projection_type = "ALL"
  }

  tags = {
    platform              = "ddc-advertising"
    product               = "rtb"
    application           = "rtb-locks"
    slackContact          = "+rtb-issues"
    application-component = "dynamodb"
    environment           = var.tag_environment
    "coxauto:ci-id"       = lookup(var.workload_mapping, var.config_services_shortname, "")
  }
}

module "firehose_vpc_interface_endpoint" {
  source               = "../../components/vpc_interface_endpoint"
  private_dns_enabled  = true
  private_subnet_names = var.private_subnets_per_az
  service_name         = "com.amazonaws.${var.region}.kinesis-firehose"
  vpc_id               = local.vpc_id
  workload_id          = lookup(var.workload_mapping, "rtb-common", "")
}

module "dynamo_vpc_service_endpoint" {
  source       = "../../components/vpc_service_endpoint"
  vpc_name     = var.vpc_name
  aws_service  = "com.amazonaws.${var.region}.dynamodb"
  subnet_names = var.all_private_subnets
  workload_id  = lookup(var.workload_mapping, "rtb-common", "")
}

module "s3_vpc_service_endpoint" {
  source       = "../../components/vpc_service_endpoint"
  subnet_names = var.all_private_subnets
  vpc_name     = var.vpc_name
  aws_service  = "com.amazonaws.${var.region}.s3"
  workload_id  = lookup(var.workload_mapping, "rtb-common", "")
}

module "breakout_stream" {
  source = "../../components/kinesis"

  retention_period_hours = 24
  stream_name            = "bidder_breakout"
  shard_count            = 1
  enabled_shard_metrics  = ["IncomingRecords"]
  lag_alerting_time      = ""
  region                 = var.region
  tag_environment        = var.tag_environment
  workload_id            = lookup(var.workload_mapping, var.bidder_app_name, "")
}

resource "aws_s3_bucket" "breakout_bucket" {
  bucket = "${var.alks_account}-${var.region}-breakout"
  lifecycle_rule {
    enabled = true
    prefix  = "bidder-breakout/raw/"

    expiration {
      days = 14
    }
  }

  lifecycle_rule {
    enabled = true
    prefix  = "all/"

    expiration {
      days = 45
    }
  }

  lifecycle_rule {
    enabled = true
    prefix  = "bid_amounts/"

    expiration {
      days = 14
    }
  }

  lifecycle_rule {
    enabled = true
    prefix  = "matched_segments/"

    expiration {
      days = 14
    }
  }

  lifecycle_rule {
    enabled = true
    prefix  = "retrieved_segments/"

    expiration {
      days = 14
    }
  }

  lifecycle_rule {
    enabled = true
    prefix  = "campaigns/"

    expiration {
      days = 14
    }
  }

  lifecycle_rule {
    enabled = true
    prefix  = "removals/"

    expiration {
      days = 14
    }
  }

  versioning {
    enabled = false
  }

  tags = {
    name                  = "${var.alks_account}-breakout-${var.region}"
    platform              = "ddc-advertising"
    product               = "rtb"
    application           = var.bidder_app_name
    application-component = var.bidder_app_name
    environment           = var.tag_environment
    slackContact          = "+rtb-issues"
    "coxauto:ci-id"       = lookup(var.workload_mapping, var.bidder_app_name, "")
    Name                  = "${var.alks_account}-${var.region}-breakout"
  }
}

module "breakout_fh" {
  source                         = "../../components/kinesis/firehose-extended"
  stream_name                    = "bidder-breakout-fh"
  firehose_bucket_arn            = replace(aws_s3_bucket.breakout_bucket.arn, "us-west-1", "us-east-1")
  firehose_buffer_size           = var.breakout_props.firehose_buffer_size
  firehose_buffer_interval       = var.breakout_props.firehose_buffer_interval
  firehose_bucket_prefix         = var.breakout_props.firehose_bucket_prefix
  error_output_prefix            = var.breakout_props.firehose_bucket_error_prefix
  firehose_role_arn              = var.breakout_props.firehose_role_arn
  firehose_s3_compression_format = "GZIP"
  region                         = var.region
  tag-environment                = var.tag_environment
  workload_id                    = lookup(var.workload_mapping, var.bidder_app_name, "")
}

#Kinesis Realtime Stream
module "rtb_stream_data_kinesis_stream" {
  source                 = "../../components/kinesis"
  shard_count            = var.rtb_realtime_data_num_shards
  enabled_shard_metrics  = var.rtb_realtime_data_kinesis_shard_metrics
  retention_period_hours = var.rtb_realtime_data_retention_hours
  stream_name            = var.rtb_realtime_data_stream_name
  lag_alerting_time      = var.rtb_realtime_data_alerting_time
  region                 = var.region
  tag_environment        = var.tag_environment
  workload_id            = lookup(var.workload_mapping, "rtb-realtime-data", "")
}


module "rtb_stream_data_firehose_destination" {
  source                         = "../../components/kinesis/firehose-stream-source"
  region                         = var.region
  tag-environment                = var.tag_environment
  stream_name                    = "${var.rtb_realtime_data_stream_name}-fh-destination"
  workload_id                    = lookup(var.workload_mapping, "rtb-realtime-data", "")
  kinesis_stream_arn             = module.rtb_stream_data_kinesis_stream.kinesis_steam_arn
  firehose_buffer_interval       = "900"
  firehose_buffer_size           = "32"
  firehose_role_arn              = "arn:aws:iam::${var.alks_account_id}:role/acct-managed/realtime-firehose-destination"
  firehose_bucket_arn            = var.realtime_firehose_bucket_destination_arn
  firehose_bucket_prefix         = "realtime-data-stream/raw/realtime-data/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/"
  firehose_bucket_error_prefix   = "realtime-data-stream/raw/result=!{firehose:error-output-type}/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/"
  destination_compression_format = "GZIP"
  role_arn                       = "arn:aws:iam::${var.alks_account_id}:role/acct-managed/realtime-firehose-destination"
}

module "rtb_rds_sns_notifications" {
  source          = "../../components/sns_with_rds_subscription"
  tag_environment = var.tag_environment
  region          = var.region

  rds_backup_db_sns_event_categories = var.rds_backup_db_sns_event_categories
  rds_backup_db_sns_identifiers      = var.rds_backup_db_sns_identifiers
  rds_backup_db_sns_source_type      = var.rds_backup_db_sns_source_type
  sns_display_name                   = var.rds_backup_sns_display_name
  sns_topic_name                     = var.rds_backup_sns_topic_name
}